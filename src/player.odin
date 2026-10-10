#+vet explicit-allocators

//
// `Player` manages everything that is tied to MPD using multithreading to
// communicate with a MPD server. It opens a MPD connection in a separate
// thread (often referred as a "client thread") and uses messages to pass data
// between threads ("commands" and "responses").
//
// `Player` is also responsible for managing the cache of song covers.
//
// Any `player_*`, `cover_*` functions are safe to use inside the main thread.
// Functions that accept the `Player_Shared` struct (not the whole player
// struct), are being ran on a separate thread.
//

package mupwit

import "base:runtime"
import "core:log"
import "core:sort"
import "core:sync/chan"
import "core:thread"
import "core:time"
import "lib:mpd"

STATUS_REQUEST_INVERVAL :: Seconds(0.5)
TARGET_CLIENT_THREAD_TPS :: 30

Source_Loc :: runtime.Source_Code_Location

Commands_Chan :: distinct chan.Chan(Player_Command)
Responses_Chan :: distinct chan.Chan(Player_Response)

Switch_Direction :: enum {
	From_None = 0, // This is the first song to be played.
	To_None, // This is the last song to be played.
	Next,
	Previous,
}

// Player events.
Event_Status_Updated :: struct {}
Event_Cur_Song_Updated :: struct {
	prev_index: Maybe(mpd.Song_Index),
	prev_id:    Maybe(mpd.Song_Id),
}
Event_Queue_Updated :: struct {}
Event_Album_List_Updated :: struct {}
Event_Song_Reordered :: struct {
	from, to: mpd.Song_Index,
}
Event_Song_Removed :: struct {
	index: mpd.Song_Index,
}
Event_Undid :: struct {
	kind: Undo_Kind,
}
Event_Redid :: struct {
	kind: Undo_Kind,
}

// Misc events.
Event_Screen_Updated :: struct {}
Event_Search :: struct {
	search: string,
}

Event :: union {
	Event_Status_Updated,
	Event_Cur_Song_Updated,
	Event_Queue_Updated,
	Event_Album_List_Updated,
	Event_Song_Reordered,
	Event_Song_Removed,
	Event_Undid,
	Event_Redid,

	//
	Event_Screen_Updated,
	Event_Search,
}

Base_Player :: struct {
	// Playback state.
	playstate:           mpd.Play_State,
	elapsed, duration:   Seconds,
	cur_song:            Maybe(mpd.Song_Index),
	cur_song_id:         Maybe(mpd.Song_Id),
	// Copy of a the last played song (before `cur_song` set to `nil`).
	// Mostly used for animation, so elements that display the current song
	// don't just disappear, but smoothly fade out with data of the last played song.
	last_played_song:    Maybe(mpd.Song),
	queue:               mpd.Song_List,
	_queue_version:      int,
	queue_duration:      Seconds,
	// Time elapsed within the queue (sum of durations of songs before the
	// current one), does not account for the current song.
	queue_elapsed:       Seconds,
	albums:              mpd.Album_List,
	// Used for "play random album" so that albums don't repeat.
	_album_pool:         [dynamic]mpd.Album_Index,
	_album_pool_drained: int,
	// In which direction current song was skipped.
	switch_direction:    Switch_Direction,
	events:              [dynamic]Event,
	history:             History,
	_status_req_timer:   Seconds,

	// Cache.
	_covers_cache:       Covers_Cache,

	//
	allocator:           runtime.Allocator,

	// Callbacks, kinda v-table.
	_connect:            proc(p: ^Base_Player, loc: Source_Loc),
	_destroy:            proc(p: ^Base_Player, loc: Source_Loc),
	_send_command:       proc(p: ^Base_Player, cmd: Player_Command, loc: Source_Loc),
	_recv_response:      proc(p: ^Base_Player, loc: Source_Loc) -> (Player_Response, bool),
}

// Player state shared between threads. All fields are thread-safe.
Player_Shared :: struct {
	commands:           Commands_Chan,
	responses:          Responses_Chan,
	covers_thread_pool: Mutex(thread.Pool),
	allocator:          runtime.Allocator,
}

Player :: struct {
	using base:     Base_Player,

	// Client state.
	_shared:        Player_Shared,
	_client_thread: ^thread.Thread,
}

player_create :: proc(allocator := context.allocator, loc := #caller_location) -> ^Player {
	player := new(Player, allocator, loc)
	_base_player_init(player, allocator, loc)

	player._connect = _player_default_connect
	player._destroy = _player_default_destroy
	player._send_command = _player_default_send_command
	player._recv_response = _player_default_recv_response

	player._shared.allocator = player.allocator
	player._client_thread = thread.create(_do_connect)
	player._client_thread.data = &player._shared

	{
		mutex := &player._shared.covers_thread_pool
		pool := mutex_lock(mutex)
		defer mutex_unlock(mutex)

		thread.pool_init(pool, player.allocator, MAX_COVER_DECODE_THREADS)
		thread.pool_start(pool)
	}

	{
		ch, err := chan.create_buffered(Commands_Chan, 10, player.allocator)
		assert(err == nil) // TODO: handle error.
		player._shared.commands = Commands_Chan(ch)
	}
	{
		ch, err := chan.create_buffered(Responses_Chan, 10, player.allocator)
		assert(err == nil) // TODO: handle error.
		player._shared.responses = Responses_Chan(ch)
	}

	return player
}

_base_player_init :: proc(
	player: ^Base_Player,
	allocator := context.allocator,
	loc := #caller_location,
) {
	player.allocator = allocator

	covers_cache_init(&player._covers_cache, player.allocator)
	history_init(&player.history, allocator)

	player._album_pool = make([dynamic]mpd.Album_Index, allocator)
}

player_connect :: proc(player: ^Base_Player, loc := #caller_location) {
	player->_connect(loc)

	player_request_albums(player)
	player_request_queue(player)
	player_request_status(player, true)
}

player_destroy :: proc(player: ^Base_Player, loc := #caller_location) {
	_player_send(player, Command_Disconnect{})

	player._destroy(player, loc)

	covers_cache_destroy(&player._covers_cache)
	history_destroy(&player.history)

	mpd.song_list_destroy(&player.queue)
	mpd.album_list_destroy(player.albums)
	_player_set_last_played_song(player, nil)
	delete(player._album_pool)

	free(player, player.allocator)
}

_player_default_connect :: proc(player: ^Base_Player, loc: Source_Loc) {
	player := cast(^Player)player
	assert(player._client_thread != nil)

	thread.start(player._client_thread)
}

_player_default_destroy :: proc(player: ^Base_Player, loc: Source_Loc) {
	player := cast(^Player)player

	thread.join(player._client_thread)
	thread.destroy(player._client_thread)

	{
		mutex := &player._shared.covers_thread_pool
		pool := mutex_lock(mutex)
		defer mutex_unlock(mutex)

		thread.pool_shutdown(pool)
		// FIXME: when calling `cover_thread_data_free` here a double-free of
		// the picture in this data occures, not sure why.
		// for task in pool.tasks_done {
		// 	data := cast(^Cover_Thread_Data)task.data
		// 	cover_thread_data_free(data)
		// }
		thread.pool_destroy(pool)
	}

	chan.destroy(&player._shared.commands)
	chan.destroy(&player._shared.responses)
}

_player_default_send_command :: proc(player: ^Base_Player, cmd: Player_Command, loc: Source_Loc) {
	player := cast(^Player)player
	chan.send(player._shared.commands, cmd)
}

_player_default_recv_response :: proc(
	player: ^Base_Player,
	loc: Source_Loc,
) -> (
	res: Player_Response,
	ok: bool,
) {
	player := cast(^Player)player
	return chan.try_recv(player._shared.responses)
}

player_update :: proc(player: ^Base_Player, dt: Seconds) {
	if player._status_req_timer > 0 {
		player._status_req_timer -= dt
		if player._status_req_timer <= 0 {
			player_request_status(player)
		}
	}

	_player_handle_responses(player)
}

// TODO!: save previous player state in the history whenever it changes outside of the app.
_player_set_status :: proc(player: ^Base_Player, status: mpd.Status, check_cur_song := false) {
	player._status_req_timer = STATUS_REQUEST_INVERVAL

	queue_changed := player._queue_version != status.queue_version

	prev_song := player.cur_song
	prev_song_id := player.cur_song_id
	if status.cur_song_id > 0 && len(player.queue) > 0 {
		player.cur_song = status.cur_song_index
		player.cur_song_id = status.cur_song_id
	} else {
		player.cur_song = nil
		player.cur_song_id = nil
	}

	if player.cur_song_id != prev_song_id && !check_cur_song {
		panic("BUG: Song changed but we've been told that it won't")
	}

	song_changed := check_cur_song && player.cur_song_id != prev_song_id

	if song_changed {
		prev, has_prev := prev_song.?
		cur, has_cur := player.cur_song.?

		if has_cur && !has_prev {
			player.switch_direction = .From_None
		} else if !has_cur && has_prev {
			player.switch_direction = .To_None

			if len(player.queue) > 0 {
				_player_set_last_played_song(player, player.queue[prev])
			}
		} else if queue_changed {
			player.switch_direction = .Next
		} else if cur > prev {
			player.switch_direction = .Next
		} else if cur < prev {
			player.switch_direction = .Previous
		}

		cur_song_title: mpd.Song_Title
		if has_cur {
			cur_song_title = player.queue[cur].title
		}

		log.debugf(
			"PLAYER: Current song changed: %v -> %v (%q), %v -> %v",
			prev_song,
			player.cur_song,
			cur_song_title,
			prev_song_id,
			player.cur_song_id,
		)
	}

	player._queue_version = status.queue_version
	player.playstate = status.playstate
	player.elapsed = Seconds(status.elapsed)
	player.duration = Seconds(status.duration)

	if song_changed {
		// TODO!!: make a proper "event system" for changes, so this code becomes more testable.
		// `when !ODIN_TEST` is a crutch for now.
		player_push_event(player, Event_Cur_Song_Updated{prev_song, prev_song_id})
		_player_queue_calc_elapsed(player)
	}

	player_push_event(player, Event_Status_Updated{})
}

_player_set_last_played_song :: proc(player: ^Base_Player, song: Maybe(mpd.Song)) {
	if last, ok := player.last_played_song.?; ok {
		mpd.song_destroy(last)
	}
	if song, ok := song.?; ok {
		player.last_played_song = mpd.song_clone(song, song.allocator)
	} else {
		player.last_played_song = nil
	}
}

_player_set_queue :: proc(player: ^Base_Player, queue: mpd.Song_List) {
	queue := queue

	// NOTE: check whether the received queue differs from the current one, so
	// the list in the queue UI doesn't get rebuilt. Because if it rebuilds it
	// cancels all animations and resets the state of the list.
	if !mpd.song_lists_differ(player.queue, queue) {
		mpd.song_list_destroy(&queue)
		log.debugf("PLAYER: Queue received, but it doesn't differ from the current one")
	} else {
		// TODO!!!: need to clear the history when queue or any other player state
		// changes outside of the app. (e.g. via `mpc` cli client or any other client)
		// If i don't do that and if the player state changes by another client,
		// the history may be invalidated, because it depended on the previous
		// player state, which was overritten.

		mpd.song_list_destroy(&player.queue)
		player.queue = queue

		_player_clamp_cur_song(player)
		_player_queue_calc_duration_and_elapsed(player)

		{
			first_file: string
			if len(queue) > 0 do first_file = string(queue[0].file)
			log.debugf("PLAYER: Queue updated: %v songs, first song = %q", len(queue), first_file)
		}

		player_push_event(player, Event_Queue_Updated{})
	}
}

_player_set_albums :: proc(player: ^Base_Player, albums: mpd.Album_List) {
	// TODO!: auto update albums when MPD database changes.
	mpd.album_list_destroy(player.albums)

	log.debugf("PLAYER: Updated albums list: %v albums", len(albums))

	// Sort in alphabetical order.
	sort_proc :: proc(a, b: mpd.Album) -> int {
		a_name := a.songs[0].album
		b_name := b.songs[0].album
		return sort.compare_strings(a_name, b_name)
	}

	sort.quick_sort_proc(albums[:], sort_proc)
	player.albums = albums

	non_zero_resize(&player._album_pool, len(albums))
	for i in 0 ..< len(albums) {
		player._album_pool[i] = mpd.Album_Index(i)
	}
	player._album_pool_drained = 0

	player_push_event(player, Event_Album_List_Updated{})
}

_player_queue_calc_duration_and_elapsed :: proc(player: ^Base_Player) {
	player.queue_elapsed = 0

	cur := player.cur_song.? or_else 0

	player.queue_duration = 0
	for song, i in player.queue {
		player.queue_duration += Seconds(song.duration)
		if i < int(cur) {
			player.queue_elapsed += Seconds(song.duration)
		}
	}
}

_player_queue_calc_elapsed :: proc(player: ^Base_Player) {
	player.queue_elapsed = 0

	cur, ok := player.cur_song.?
	if !ok do return

	for song, i in player.queue {
		if i >= int(cur) do break
		player.queue_elapsed += Seconds(song.duration)
	}
}

_player_clamp_cur_song :: proc(player: ^Base_Player) {
	cur, ok := player.cur_song.?
	if ok && !within(int(cur), 0, len(player.queue)) {
		player.cur_song = nil
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
	changes := changes
	if changes == nil do return

	if .Playlist in changes {
		log.debugf("PLAYER: Queue changed, requesting up-to-date queue")

		queue := mpd.request_queue(client, shared.allocator) or_return
		_response_send(shared.responses, Response_Queue{queue})
		changes |= {.Player}
	}
	if .Player in changes {
		log.debugf("PLAYER: Status changed, requesting up-to-date status")

		status := mpd.request_status(client) or_return
		_response_send_status(shared.responses, status, true)
	}

	return nil
}

player_push_event :: proc(player: ^Base_Player, event: Event) {
	append(&player.events, event)
}

player_progress :: proc(player: ^Base_Player) -> f32 {
	if player.duration <= 0 do return 0.0
	return f32(player.elapsed / player.duration)
}

player_cur_song :: proc(player: ^Base_Player) -> (song: ^mpd.Song, ok: bool) {
	if len(player.queue) > 0 {
		index := player.cur_song.? or_return
		song = &player.queue[index]
		ok = true
	}
	return
}
player_cur_or_last_song :: proc(player: ^Base_Player) -> (song: ^mpd.Song, ok: bool) {
	song, ok = player_cur_song(player)
	if ok do return
	return &player.last_played_song.?
}
