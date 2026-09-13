package mupwit

import "core:log"
import "core:sync/chan"
import "lib:mpd"

// ------------------------------
// Command.
// ------------------------------

Command_Request_Status :: struct {}
Command_Request_Queue :: struct {}

Command_Play :: struct {}
Command_Resume :: struct {}
Command_Pause :: struct {}
Command_Stop :: struct {}
Command_Seek :: struct {
	seconds: Seconds,
}

Command_Disconnect :: struct {}

Command :: union #no_nil {
	Command_Request_Status,
	Command_Request_Queue,
	Command_Play,
	Command_Resume,
	Command_Pause,
	Command_Stop,
	Command_Seek,
	Command_Disconnect,
}

_player_send_command :: proc(command: Command) {
	chan.send(state.player.commands, command)
}

// ------------------------------
// Playback commands.
// ------------------------------

player_toggle_play :: proc() {
	switch state.player.playstate {
	case .Play:
		_player_send_command(Command_Pause{})
		state.player.playstate = .Pause
	case .Pause:
		_player_send_command(Command_Resume{})
		state.player.playstate = .Play
	case .Stop:
		_player_send_command(Command_Play{})
		state.player.playstate = .Play
	}
}

player_seek :: proc(seconds: Seconds) {
	_player_send_command(Command_Seek{seconds})

	// Update local elapsed time so the slider doesn't jump untill player
	// receives an up-to-date status.
	state.player.elapsed = seconds
}

player_seek_percent :: proc(percent: f32) {
	secs := Seconds(percent) * state.player.duration
	player_seek(secs)
}

// ------------------------------
// Request commands.
// ------------------------------

player_request_status :: proc() {
	_player_send_command(Command_Request_Status{})
}
player_request_queue :: proc() {
	_player_send_command(Command_Request_Queue{})
}

// ------------------------------
// Handle.
// ------------------------------

_player_handle_commands :: proc(client: ^mpd.Client) -> (should_exit: bool) {
	player := &state.player

	for command in chan.try_recv(player.commands) {
		_, should_exit = command.(Command_Disconnect)
		if should_exit do return

		err := _player_handle_command(client, command)
		if err != nil {
			log.errorf("Failed to handle command %v: %v", command, err)
		}
	}

	return false
}

_player_handle_command :: proc(client: ^mpd.Client, command: Command) -> (err: mpd.Error) {
	switch cmd in command {
	case Command_Request_Status:
		status := mpd.request_status(client) or_return
		player_send_response(status)

	case Command_Request_Queue:
		queue := mpd.request_queue(client, context.allocator) or_return
		player_send_response(Response_Queue{queue})

	case Command_Play:
		mpd.send_and_forget(client, "play") or_return
	case Command_Resume:
		mpd.send_and_forget(client, "pause 0") or_return
	case Command_Pause:
		mpd.send_and_forget(client, "pause 1") or_return
	case Command_Stop:
		mpd.send_and_forget(client, "stop") or_return
	case Command_Seek:
		mpd.send_and_forget(client, "seekcur", cmd.seconds) or_return

	case Command_Disconnect: // Do nothing.
	}

	return nil
}
