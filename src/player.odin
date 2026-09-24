#+vet explicit-allocators

// FIXME!!!: MUPWIT may freeze if queue changes too quickly.
// I don't know where the freeze happens because it may also freeze the main
// thread which stops the app from responding, but sometimes only the player
// thread freezes. Net-programming is fucking hard...
// May be i should implement some kind of debounce to not request the queue
// info right after it being changed?

// TODO!: undo histroy.

package mupwit

import "base:runtime"
import "core:sort"
import "core:sync/chan"
import "core:thread"
import "core:time"
import "lib:mpd"

STATUS_REQUEST_INVERVAL :: Seconds(0.5)
TARGET_CLIENT_THREAD_TPS :: 30

Commands_Chan :: distinct chan.Chan(Command)
Responses_Chan :: distinct chan.Chan(Response)

Switch_Direction :: enum {
	From_None = 0, // This is the first song to be played.
	To_None, // This is the last song to be played.
	Next,
	Previous,
}

// Player state shared between threads. All fields are thread-safe.
Player_Shared :: struct {
	commands:           Commands_Chan,
	responses:          Responses_Chan,
	covers_thread_pool: Mutex(thread.Pool),
	allocator:          runtime.Allocator,
}

Player :: struct {
	// Playback state.
	playstate:                 mpd.Play_State,
	elapsed, duration:         Seconds,
	cur_song:                  Maybe(mpd.Song_Index),
	// Copy of a the last played song (before `cur_song` set to `nil`).
	// Mostly used for animation, so elements that display the current song
	// don't just disappear, but smoothly fade out with data of the last played song.
	last_played_song:          Maybe(mpd.Song),
	queue:                     mpd.Song_List,
	queue_duration:            Seconds,
	// Time elapsed within the queue (sum of durations of songs before the
	// current one), does not account for the current song.
	queue_elapsed:             Seconds,
	albums:                    mpd.Album_List,
	// In which direction current song was skipped.
	switch_direction:          Switch_Direction,

	// Cache.
	_covers_cache:             Covers_Cache,

	// Flags.
	// Whether to ignore the next incoming "queue" response. Usually set after
	// reordering items so it doesn't rebuild the items list.
	_ignore_next_queue_update: bool,

	// Client state.
	_shared:                   Player_Shared,
	_client_thread:            ^thread.Thread,
	_status_req_timer:         Seconds,

	//
	allocator:                 runtime.Allocator,
}

player_init :: proc(player: ^Player, allocator := context.allocator) {
	player.allocator = allocator
	player._shared.allocator = allocator

	player._client_thread = thread.create(_do_connect)
	player._client_thread.data = &player._shared

	player._covers_cache = make(Covers_Cache, allocator)

	{
		mutex := &player._shared.covers_thread_pool
		pool := mutex_lock(mutex)
		defer mutex_unlock(mutex)

		thread.pool_init(pool, player.allocator, MAX_COVER_DECODE_THREADS)
		thread.pool_start(pool)
	}

	{
		ch, err := chan.create_buffered(chan.Chan(Command), 10, player.allocator)
		assert(err == nil) // TODO: handle error.
		player._shared.commands = Commands_Chan(ch)
	}
	{
		ch, err := chan.create_buffered(chan.Chan(Response), 10, player.allocator)
		assert(err == nil) // TODO: handle error.
		player._shared.responses = Responses_Chan(ch)
	}
}

player_connect :: proc(player: ^Player) {
	assert(player._client_thread != nil)

	thread.start(player._client_thread)

	player_request_status(player)
	player_request_queue(player)
	player_request_albums(player)
}

player_destroy :: proc(player: ^Player) {
	_command_send(player._shared.commands, Command_Disconnect{})

	thread.join(player._client_thread)
	thread.destroy(player._client_thread)

	{
		mutex := &player._shared.covers_thread_pool
		pool := mutex_lock(mutex)
		defer mutex_unlock(mutex)

		thread.pool_shutdown(pool)
		thread.pool_destroy(pool)
	}

	_covers_cache_destroy(player._covers_cache)

	mpd.song_list_destroy(&player.queue)
	mpd.album_list_destroy(player.albums)
	_player_set_last_played_song(player, nil)

	chan.destroy(&player._shared.commands)
	chan.destroy(&player._shared.responses)
}

player_update :: proc(player: ^Player, dt: Seconds) {
	player._status_req_timer -= dt
	if player._status_req_timer <= 0 {
		player_request_status(player)
		player._status_req_timer = STATUS_REQUEST_INVERVAL
	}

	for response in chan.try_recv(player._shared.responses) {
		_player_handle_response(player, response)
	}
}

_player_set_status :: proc(player: ^Player, status: mpd.Status) {
	player.playstate = status.playstate
	player.elapsed = Seconds(status.elapsed)
	player.duration = Seconds(status.duration)

	prev_index := player.cur_song
	if status.cur_song_id > 0 && len(player.queue) > 0 {
		player.cur_song = status.cur_song_index
	} else {
		player.cur_song = nil
	}

	prev, has_prev := prev_index.?
	cur, has_cur := player.cur_song.?

	if cur != prev || has_prev != has_cur {
		if !has_prev && has_cur {
			player.switch_direction = .From_None
		} else if has_prev && !has_cur {
			player.switch_direction = .To_None
			player.queue_elapsed = 0

			if len(player.queue) > 0 {
				prev_song := player.queue[prev]
				_player_set_last_played_song(player, prev_song)
			}
		} else if cur > prev {
			player.switch_direction = .Next
		} else if cur < prev {
			player.switch_direction = .Previous
		}

		_player_queue_calc_elapsed(player)
	}

	if prev_index != player.cur_song {
		on_cur_song_updated(prev_index)
	}
}

_player_set_last_played_song :: proc(player: ^Player, song: Maybe(mpd.Song)) {
	if last, ok := player.last_played_song.?; ok {
		mpd.song_destroy(last)
	}
	if song, ok := song.?; ok {
		player.last_played_song = mpd.song_clone(song, song.allocator)
	} else {
		player.last_played_song = nil
	}
}

_player_set_queue :: proc(player: ^Player, queue: mpd.Song_List) {
	queue := queue

	if player._ignore_next_queue_update {
		player._ignore_next_queue_update = false
		// TODO: i should probably use the `playlist` version field of a
		// MPD status instead of `mpd.song_lists_differ`.
		if !mpd.song_lists_differ(player.queue, queue) {
			mpd.song_list_destroy(&queue)
			return
		}
	}

	mpd.song_list_destroy(&player.queue)
	player.queue = queue

	_player_queue_calc_duration(player)

	on_queue_updated()
}

_player_set_albums :: proc(player: ^Player, albums: mpd.Album_List) {
	// TODO!: auto update albums when MPD database changes.
	mpd.album_list_destroy(player.albums)

	// Sort in alphabetical order.
	sort_proc :: proc(a, b: mpd.Album) -> int {
		a_name := a.songs[0].album
		b_name := b.songs[0].album
		return sort.compare_strings(a_name, b_name)
	}

	sort.quick_sort_proc(albums[:], sort_proc)
	player.albums = albums

	on_albums_updated()
}

_player_queue_calc_duration :: proc(player: ^Player) {
	player.queue_duration = 0
	for song in player.queue {
		player.queue_duration += Seconds(song.duration)
	}
}

_player_queue_calc_elapsed :: proc(player: ^Player) {
	cur, ok := player.cur_song.?
	if !ok do return

	player.queue_elapsed = 0
	for song, i in player.queue {
		if i >= int(cur) do break
		player.queue_elapsed += Seconds(song.duration)
	}
}

_do_connect :: proc(t: ^thread.Thread) {
	context.logger = make_logger()

	// NOTE: this thread may log stuff into a console in a non-thread safe
	// fashion and overlapping logs may appear, which is not that bad i guess?

	TARGET_DELAY :: time.Second / TARGET_CLIENT_THREAD_TPS
	MIN_DELAY :: 5 * time.Millisecond

	shared := cast(^Player_Shared)t.data

	client, err := mpd.connect(shared.allocator)
	assert(err == nil) // TODO: handle error.
	defer mpd.disconnect(&client)

	start := time.now()
	for {
		changes, _ := mpd.request_changes(&client)
		_ = _player_handle_changes(shared, &client, changes)

		should_exit := _player_handle_commands(shared, &client)
		if should_exit do break

		now := time.now()
		elapsed := time.diff(start, now)
		start = now
		time.sleep(max(TARGET_DELAY - elapsed, MIN_DELAY))
	}
}

@(require_results)
_player_handle_changes :: proc(
	shared: ^Player_Shared,
	client: ^mpd.Client,
	changes: mpd.Changes,
) -> (
	err: mpd.Error,
) {
	if changes == nil do return

	if .Player in changes {
		status := mpd.request_status(client) or_return
		_response_send(shared.responses, status)
	}
	if .Playlist in changes {
		queue := mpd.request_queue(client, shared.allocator) or_return
		status := mpd.request_status(client) or_return
		_response_send(shared.responses, Response_Queue{queue, status})
	}

	return nil
}

player_progress :: proc(player: ^Player) -> f32 {
	if player.duration <= 0 do return 0.0
	return f32(player.elapsed / player.duration)
}

player_cur_song :: proc(player: ^Player) -> (song: ^mpd.Song, ok: bool) {
	if len(player.queue) > 0 {
		index := player.cur_song.? or_return
		song = &player.queue[index]
		ok = true
	}
	return
}
player_cur_or_last_song :: proc(player: ^Player) -> (song: ^mpd.Song, ok: bool) {
	song, ok = player_cur_song(player)
	if ok do return
	return &player.last_played_song.?
}
