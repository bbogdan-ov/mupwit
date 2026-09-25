package mupwit

import "base:intrinsics"
import "base:runtime"
import "core:log"
import "core:math"
import "core:strings"
import "core:sync/chan"
import "lib:mpd"
import "lib:ui"

// ------------------------------
// Command.
// ------------------------------

Command_Request_Status :: struct {}
Command_Request_Queue :: struct {}
Command_Request_Albums :: struct {}

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
Command_Seek_Current :: struct {
	seconds: Seconds,
}
Command_Seek_Song :: struct {
	index:   mpd.Song_Index,
	seconds: Seconds,
}
Command_Reorder_Song :: struct {
	from, to: mpd.Song_Index,
}
Command_Remove_Song :: struct {
	index: mpd.Song_Index,
}
Command_Shuffle_Queue :: struct {}
Command_Clear_Queue :: struct {}

Command_Disconnect :: struct {}

Command :: union #no_nil {
	Command_Request_Status,
	Command_Request_Queue,
	Command_Request_Albums,
	Command_Request_Cover,
	Command_Play,
	Command_Next,
	Command_Previous,
	Command_Resume,
	Command_Pause,
	Command_Stop,
	Command_Play_Song,
	Command_Seek_Current,
	Command_Seek_Song,
	Command_Reorder_Song,
	Command_Remove_Song,
	Command_Shuffle_Queue,
	Command_Clear_Queue,
	Command_Disconnect,
}

_command_destroy :: proc(command: Command) {
	#partial switch cmd in command {
	case Command_Request_Cover:
		delete(string(cmd.file), cmd.allocator)
		delete(string(cmd.key), cmd.allocator)
	}
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
	if player.cur_song == nil do return

	// Update local elapsed time so the slider doesn't jump untill player
	// receives an up-to-date status.
	seconds := max(seconds, 0)
	if seconds >= player.duration {
		// NOTE: its a crutch, sometimes when seeking at the end of a song, MPD
		// fails to do that, probably because `seconds` may be a little greater
		// that song's duration due to float precision.
		seconds = math.floor(player.duration)
	}
	player.elapsed = seconds

	if player.playstate == .Stop {
		_command_send(player._shared.commands, Command_Play{})
		_command_send(player._shared.commands, Command_Seek_Current{seconds})
		// FIXME!: `seek <index> <time>` doesn't seem to do anything?? Well done MPD.
		// `play` and `seekcur <time>` sequence also doesn't seem to work.
		// _command_send(player._shared.commands, Command_Seek_Song{index, seconds})
	} else {
		_command_send(player._shared.commands, Command_Seek_Current{seconds})
	}
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

	player._ignore_next_queue_update = true
	// Duration shouldn't change, but just in case.
	_player_queue_calc_duration_and_elapsed(player)
	on_song_reordered(from, to)

	_command_send(player._shared.commands, Command_Reorder_Song{from, to})
}

player_remove_song :: proc(player: ^Player, index: mpd.Song_Index) {
	assert(0 <= index && int(index) < len(player.queue))

	mpd.song_destroy(player.queue[index])
	ordered_remove(&player.queue, int(index))

	cur_song, has_cur_song := player.cur_song.?
	if has_cur_song && cur_song > index {
		player.cur_song = cur_song - 1
	}

	player._ignore_next_queue_update = true
	_player_queue_calc_duration_and_elapsed(player)
	on_song_removed(index)

	_command_send(player._shared.commands, Command_Remove_Song{index})
}

player_shuffle_queue :: proc(player: ^Player) {
	if len(player.queue) <= 1 do return
	_command_send(player._shared.commands, Command_Shuffle_Queue{})
}
player_clear_queue :: proc(player: ^Player) {
	if len(player.queue) == 0 do return
	_command_send(player._shared.commands, Command_Clear_Queue{})
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
player_request_albums :: proc(player: ^Player) {
	_command_send(player._shared.commands, Command_Request_Albums{})
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
	defer _command_destroy(command)

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

	case Command_Request_Albums:
		albums := mpd.request_albums(client, shared.allocator) or_return
		_response_send(shared.responses, albums)
		return nil

	case Command_Request_Cover:
		// FIXME: this command may block the client thread for some time (usually
		// around 60-80ms) and while the client thread is blocked it may not be
		// able to proccess other commands. Should come up with a way to split
		// picture data reciving into multiple steps.
		// After picture data is received (png, jpeg, etc), it is sent to
		// another thread and being decoded here, so it doesn't block the
		// client thread.

		// TODO!: should reuse cover surface with same key and of the larger
		// size and down scale it instead of requesting picture data for every
		// cover request.
		picture, missing := mpd.request_song_picture(client, cmd.file, shared.allocator) or_return
		if missing {
			key := cover_key_clone(cmd.key, shared.allocator)
			res := Response_Cover{key, cmd.size, nil, {}, shared.allocator}
			_response_send(shared.responses, res)
			return nil
		} else {
			_cover_decode_and_send(shared, cmd.key, cmd.size, picture)
			return nil
		}

	case Command_Play:
		return mpd.send_and_forget(client, "play")
	case Command_Next:
		return mpd.send_and_forget(client, "nextbobo")
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
	case Command_Seek_Current:
		return mpd.send_and_forget(client, "seekcur", cmd.seconds)
	case Command_Seek_Song:
		return mpd.send_and_forget(client, "seek", cmd.index, cmd.seconds)
	case Command_Reorder_Song:
		mpd.send_and_forget(client, "move", cmd.from, cmd.to) or_return
		status := mpd.request_status(client) or_return
		_response_send(shared.responses, status)
		return nil
	case Command_Remove_Song:
		mpd.send_and_forget(client, "delete", cmd.index) or_return
		status := mpd.request_status(client) or_return
		_response_send(shared.responses, status)
		return nil
	case Command_Shuffle_Queue:
		return mpd.send_and_forget(client, "shuffle")
	case Command_Clear_Queue:
		return mpd.send_and_forget(client, "clear")

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
	// TODO!!: handle only one `Command_Request_Cover` per client loop step.
	// Currently all commands are handled in order in one step, including
	// `Command_Request_Cover`, multiple cover requests in a row may block the
	// client loop for some time due to picture data receiving is done in this
	// thread too.
	for command in chan.try_recv(shared.commands) {
		_, should_exit = command.(Command_Disconnect)
		if should_exit do return

		err := _player_handle_command(shared, client, command)
		if err != nil {
			// TODO: display errors to the user.
			log.errorf("Failed to handle command %v: %v", command, err)
		}
	}

	return false
}
