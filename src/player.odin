#+vet explicit-allocators

// FIXME!!!: MUPWIT may freeze if queue changes too quickly.
// I don't know where the freeze happens because it may also freeze the main
// thread which stops the app from responding, but sometimes only the player
// thread freezes. Net-programming is fucking hard...
// May be i should implement some kind of debounce to not request the queue
// info right after it being changed?

package mupwit

import "base:runtime"
import "core:sync/chan"
import "core:thread"
import "core:time"
import "lib:mpd"

STATUS_REQUEST_INVERVAL :: Seconds(0.5)
TARGET_CLIENT_THREAD_TPS :: 30

Player :: struct {
	// Playback state.
	playstate:        mpd.Play_State,
	cur_song:         Maybe(mpd.Song_Handle),
	queue:            mpd.Song_List,

	// Client state.
	thread:           ^thread.Thread,
	commands:         chan.Chan(Command),
	responses:        chan.Chan(Response),
	status_req_timer: Seconds,
}

player_connect :: proc() {
	player := &state.player

	player.thread = thread.create(_do_connect)
	thread.start(player.thread)

	chan_err: runtime.Allocator_Error
	player.commands, chan_err = chan.create_buffered(chan.Chan(Command), 10, context.allocator)
	assert(chan_err == nil) // TODO: handle error.
	player.responses, chan_err = chan.create_buffered(chan.Chan(Response), 10, context.allocator)
	assert(chan_err == nil) // TODO: handle error.

	player_request_status()
	player_request_queue()
}

player_destroy :: proc() {
	player := &state.player

	player_send_command(Command_Disconnect{})

	thread.join(player.thread)

	mpd.song_list_destroy(&player.queue)
	chan.destroy(&player.commands)
	chan.destroy(&player.responses)
}

player_update :: proc(dt: Seconds) {
	player := &state.player

	player.status_req_timer -= dt
	if player.status_req_timer <= 0 {
		player_request_status()
		player.status_req_timer = STATUS_REQUEST_INVERVAL
	}

	for response in chan.try_recv(player.responses) {
		_player_handle_response(response)
	}
}

_do_connect :: proc(t: ^thread.Thread) {
	context.logger = make_logger()

	// NOTE: this thread may log stuff into console in a non-thread safe
	// fashion and overlapping logs may appear, which is not that bad i guess?

	TARGET_DELAY :: time.Second / TARGET_CLIENT_THREAD_TPS
	MIN_DELAY :: 5 * time.Millisecond

	client, err := mpd.connect(context.allocator)
	assert(err == nil) // TODO: handle error.
	defer mpd.disconnect(&client)

	start := time.now()
	for {
		changes, _ := mpd.request_changes(&client)
		_ = _player_handle_changes(&client, changes)

		should_exit := _player_handle_commands(&client)
		if should_exit do break

		now := time.now()
		elapsed := time.diff(start, now)
		start = now
		time.sleep(max(TARGET_DELAY - elapsed, MIN_DELAY))
	}
}

@(require_results)
_player_handle_changes :: proc(client: ^mpd.Client, changes: mpd.Changes) -> (err: mpd.Error) {
	if changes == nil do return

	if .Player in changes {
		status := mpd.request_status(client) or_return
		player_send_response(status)
	}
	if .Playlist in changes {
		queue := mpd.request_queue(client, context.allocator) or_return
		player_send_response(Response_Queue{queue})
	}

	return nil
}
