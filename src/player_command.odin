package mupwit

import "base:intrinsics"
import "base:runtime"
import "core:log"
import "core:strings"
import "core:sync/chan"
import "lib:mpd"
import "lib:ui"

// ------------------------------
// Command.
// ------------------------------

Command_Request_Status :: struct {}
Command_Request_Queue :: struct {}

Command_Request_Cover :: struct {
	key:       Cover_Key,
	file:      mpd.Song_File,
	size:      Cover_Size,
	allocator: runtime.Allocator,
}

Command_Play :: struct {}
Command_Next :: struct {}
Command_Previous :: struct {}
Command_Resume :: struct {}
Command_Pause :: struct {}
Command_Stop :: struct {}
Command_Play_Song :: struct {
	index: mpd.Song_Index,
}
Command_Seek :: struct {
	seconds: Seconds,
}
Command_Reorder_Song :: struct {
	from, to: mpd.Song_Index,
}

Command_Disconnect :: struct {}

Command :: union #no_nil {
	Command_Request_Status,
	Command_Request_Queue,
	Command_Request_Cover,
	Command_Play,
	Command_Next,
	Command_Previous,
	Command_Resume,
	Command_Pause,
	Command_Stop,
	Command_Play_Song,
	Command_Seek,
	Command_Reorder_Song,
	Command_Disconnect,
}

_command_send :: proc(ch: Commands_Chan, command: Command) {
	chan.send(ch, command)
}

// ------------------------------
// Playback commands.
// ------------------------------

player_toggle_play :: proc(player: ^Player) {
	cmds := player._shared.commands

	switch player.playstate {
	case .Play:
		_command_send(cmds, Command_Pause{})
		player.playstate = .Pause
	case .Pause:
		_command_send(cmds, Command_Resume{})
		player.playstate = .Play
	case .Stop:
		_command_send(cmds, Command_Play{})
		player.playstate = .Play
	}
}

player_next :: proc(player: ^Player) {
	_command_send(player._shared.commands, Command_Next{})
}
player_previous :: proc(player: ^Player) {
	_command_send(player._shared.commands, Command_Previous{})
}

player_play_song :: proc(player: ^Player, index: mpd.Song_Index, force := false) {
	if !force && player.cur_song == index do return

	_command_send(player._shared.commands, Command_Play_Song{index})
}

player_seek :: proc(player: ^Player, seconds: Seconds) {
	_command_send(player._shared.commands, Command_Seek{seconds})

	// Update local elapsed time so the slider doesn't jump untill player
	// receives an up-to-date status.
	player.elapsed = seconds
}

player_seek_percent :: proc(player: ^Player, percent: f32) {
	secs := Seconds(percent) * player.duration
	player_seek(player, secs)
}

player_reorder_song :: proc(player: ^Player, from, to: mpd.Song_Index) {
	if from == to do return

	ui.slice_reorder(player.queue[:], int(from), int(to))

	cur_song, has_cur_song := player.cur_song.?
	if has_cur_song {
		player.cur_song = ui.shifted_index(cur_song, from, to)
	}

	on_song_reordered(from, to)
	_command_send(player._shared.commands, Command_Reorder_Song{from, to})
}

// ------------------------------
// Request commands.
// ------------------------------

player_request_status :: proc(player: ^Player) {
	_command_send(player._shared.commands, Command_Request_Status{})
}
player_request_queue :: proc(player: ^Player) {
	_command_send(player._shared.commands, Command_Request_Queue{})
}

player_request_cover :: proc(
	player: ^Player,
	file: mpd.Song_File,
	album: mpd.Album_Name,
	size: Cover_Size,
) {
	alloc := player.allocator

	file := mpd.Song_File(strings.clone(string(file), alloc))
	key := cover_key_make_cloned(file, album, alloc)
	cmd := Command_Request_Cover{key, file, size, alloc}
	_command_send(player._shared.commands, cmd)
}

// ------------------------------
// Handle.
// ------------------------------

_player_handle_command :: proc(
	shared: ^Player_Shared,
	client: ^mpd.Client,
	command: Command,
) -> (
	err: mpd.Error,
) {
	switch cmd in command {
	case Command_Request_Status:
		status := mpd.request_status(client) or_return
		_response_send(shared.responses, status)
		return nil

	case Command_Request_Queue:
		queue := mpd.request_queue(client, shared.allocator) or_return
		status := mpd.request_status(client) or_return
		_response_send(shared.responses, Response_Queue{queue, status})
		return nil

	case Command_Request_Cover:
		defer {
			delete(string(cmd.file), cmd.allocator)
			delete(string(cmd.key), cmd.allocator)
		}

		picture, missing := mpd.request_song_picture(client, cmd.file, shared.allocator) or_return
		if missing {
			res := Response_Cover {
				key       = cover_key_clone(cmd.key, shared.allocator),
				size      = cmd.size,
				surface   = nil,
				allocator = shared.allocator,
			}
			_response_send(shared.responses, res)
			return nil
		} else {
			_cover_decode_and_send(shared, cmd.key, cmd.size, picture)
			return nil
		}

	case Command_Play:
		return mpd.send_and_forget(client, "play")
	case Command_Next:
		return mpd.send_and_forget(client, "next")
	case Command_Previous:
		return mpd.send_and_forget(client, "previous")
	case Command_Resume:
		return mpd.send_and_forget(client, "pause 0")
	case Command_Pause:
		return mpd.send_and_forget(client, "pause 1")
	case Command_Stop:
		return mpd.send_and_forget(client, "stop")
	case Command_Play_Song:
		return mpd.send_and_forget(client, "play", cmd.index)
	case Command_Seek:
		return mpd.send_and_forget(client, "seekcur", cmd.seconds)
	case Command_Reorder_Song:
		mpd.send_and_forget(client, "move", cmd.from, cmd.to) or_return
		status := mpd.request_status(client) or_return
		_response_send(shared.responses, status)
		return nil

	case Command_Disconnect:
		// Do nothing.
		return nil

	case:
		unreachable()
	}
}

_player_handle_commands :: proc(
	shared: ^Player_Shared,
	client: ^mpd.Client,
) -> (
	should_exit: bool,
) {
	for command in chan.try_recv(shared.commands) {
		_, should_exit = command.(Command_Disconnect)
		if should_exit do return

		err := _player_handle_command(shared, client, command)
		if err != nil {
			log.errorf("Failed to handle command %v: %v", command, err)
		}
	}

	return false
}
