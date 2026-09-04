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
Command_Pause :: struct {}
Command_Stop :: struct {}

Command_Disconnect :: struct {}

Command :: union #no_nil {
	Command_Request_Status,
	Command_Request_Queue,
	Command_Play,
	Command_Pause,
	Command_Stop,
	Command_Disconnect,
}

player_send_command :: proc(command: Command) {
	chan.send(state.player.commands, command)
}

player_request_status :: proc() {
	player_send_command(Command_Request_Status{})
}
player_request_queue :: proc() {
	player_send_command(Command_Request_Queue{})
}

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
		panic("TODO!!!: Command_Play")
	case Command_Pause:
		panic("TODO!!!: Command_Pause")
	case Command_Stop:
		panic("TODO!!!: Command_Stop")
	case Command_Disconnect: // Do nothing.
	}

	return nil
}

// ------------------------------
// Respose.
// ------------------------------

Response_Queue :: struct {
	list: mpd.Song_List,
}

Response :: union {
	mpd.Status,
	Response_Queue,
}

player_send_response :: proc(response: Response) {
	chan.send(state.player.responses, response)
}

_player_handle_response :: proc(response: Response) {
	player := &state.player

	switch res in response {
	case mpd.Status:
		player.playstate = res.playstate

		if res.cur_song_id > 0 {
			player.cur_song = mpd.Song_Handle{res.cur_song_id, res.cur_song_number}
		} else {
			player.cur_song = nil
		}

	case Response_Queue:
		mpd.song_list_destroy(&player.queue)
		player.queue = res.list
	}
}
