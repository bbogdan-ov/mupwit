package mupwit

import "base:intrinsics"
import "base:runtime"
import "core:log"
import "core:math"
import "core:math/rand"
import "core:strings"
import "core:sync/chan"
import "lib:mpd"
import "lib:ui"

// ------------------------------
// Command.
// ------------------------------

// Request commands.

Command_Request_Status :: struct {
	check_cur_song: bool,
}
Command_Request_Queue :: struct {}
Command_Request_Albums :: struct {}

Command_Request_Cover :: struct {
	key:       Cover_Key,
	file:      mpd.Song_File,
	size:      Cover_Size,
	allocator: runtime.Allocator `fmt:"-"`,
}

// Playback commands.

Command_Play :: struct {}
Command_Next :: struct {}
Command_Previous :: struct {}
Command_Resume :: struct {}
Command_Pause :: struct {}
Command_Stop :: struct {}
Command_Seek :: struct {
	seconds: Seconds,
}

// Queue commands.

Command_Load :: struct {
	files:     []mpd.Song_File `fmt:"-"`,
	play:      Maybe(mpd.Song_Index),
	seek:      Seconds,
	allocator: runtime.Allocator `fmt:"-"`,
}
Command_Load_Album :: struct {
	name:      mpd.Album_Name,
	allocator: runtime.Allocator `fmt:"-"`,
}
Command_Queue_Play :: struct {
	index: mpd.Song_Index,
	seek:  Seconds,
}
Command_Queue_Add :: struct {
	file:      mpd.Song_File,
	index:     mpd.Song_Index,
	play:      bool,
	allocator: runtime.Allocator `fmt:"-"`,
}
Command_Queue_Remove :: struct {
	index: mpd.Song_Index,
}
Command_Queue_Reorder :: struct {
	from, to: mpd.Song_Index,
}
Command_Queue_Shuffle :: struct {}
Command_Queue_Clear :: struct {}

// Misc commands.

Command_Disconnect :: struct {}

Player_Command :: union #no_nil {
	// Request commands.
	Command_Request_Status,
	Command_Request_Queue,
	Command_Request_Albums,
	Command_Request_Cover,

	// Playback commands.
	Command_Play,
	Command_Next,
	Command_Previous,
	Command_Resume,
	Command_Pause,
	Command_Stop,
	Command_Seek,

	// Queue commands.
	Command_Load,
	Command_Load_Album,
	Command_Queue_Play,
	Command_Queue_Add,
	Command_Queue_Remove,
	Command_Queue_Reorder,
	Command_Queue_Shuffle,
	Command_Queue_Clear,

	// Misc commands.
	Command_Disconnect,
}

_command_destroy :: proc(command: Player_Command, loc := #caller_location) {
	#partial switch cmd in command {
	case Command_Request_Cover:
		delete(string(cmd.file), cmd.allocator, loc)
		cover_key_delete(cmd.key, cmd.allocator, loc)
	case Command_Load_Album:
		delete(cmd.name, cmd.allocator, loc)
	case Command_Queue_Add:
		delete(string(cmd.file), cmd.allocator, loc)
	case Command_Load:
		for file in cmd.files do delete(string(file), cmd.allocator, loc)
		delete(cmd.files, cmd.allocator, loc)
	}
}

_player_send :: proc(player: ^Base_Player, command: Player_Command, loc := #caller_location) {
	#partial switch cmd in command {
	case Command_Play:
		player.playstate = .Play
	case Command_Resume:
		player.playstate = .Play
	case Command_Pause:
		player.playstate = .Pause
	case Command_Stop:
		player.playstate = .Stop

	case Command_Queue_Play, Command_Next, Command_Previous:
		cur := player.cur_song.? or_break
		_player_history_push(player, .Song_Switch, Command_Queue_Play{cur, player.elapsed})

	case Command_Seek:
		_player_history_push(player, .Seek, Command_Seek{player.elapsed})
		player.elapsed = cmd.seconds

	case Command_Queue_Reorder:
		_player_history_push(player, .Queue_Reorder, Command_Queue_Reorder{cmd.to, cmd.from})

		ui.slice_reorder(player.queue[:], int(cmd.from), int(cmd.to))

		cur_song, has_cur_song := player.cur_song.?
		if has_cur_song {
			player.cur_song = ui.shifted_index(cur_song, cmd.from, cmd.to)
		}

		// Duration shouldn't change, but just in case.
		_player_queue_calc_duration_and_elapsed(player)
		when !ODIN_TEST do on_song_reordered(cmd.from, cmd.to)

	case Command_Queue_Add:
		_player_history_push(player, .Queue_Add, Command_Queue_Remove{cmd.index})

	case Command_Queue_Remove:
		{
			song := &player.queue[cmd.index]
			play := player.cur_song == cmd.index
			c := cmd_make_queue_add(player, song.file, cmd.index, play)
			_player_history_push(player, .Queue_Remove, c)
		}

		mpd.song_destroy(player.queue[cmd.index])
		ordered_remove(&player.queue, int(cmd.index))

		cur_song, has_cur_song := player.cur_song.?
		if has_cur_song {
			if cur_song == cmd.index {
				player.cur_song = nil
			} else if cur_song > cmd.index {
				player.cur_song = cur_song - 1
			}
			_player_clamp_cur_song(player)
		}

		_player_queue_calc_duration_and_elapsed(player)
		when !ODIN_TEST do on_song_removed(cmd.index)

	case Command_Load:
		_player_history_push_queue(player, .Load)
	case Command_Load_Album:
		// TODO!: should save only the previous album name in the history
		// intead of the whole queue.
		_player_history_push_queue(player, .Load_Album)
	case Command_Queue_Shuffle:
		_player_history_push_queue(player, .Queue_Shuffle)
	case Command_Queue_Clear:
		_player_history_push_queue(player, .Queue_Clear)
	}

	player.vtable.send_command(player, command, loc)
}

// ------------------------------
// Commands.
// Functions to use outside of `player_*` files.
// ------------------------------

// Request commands.

player_request_status :: proc(player: ^Base_Player, check_cur_song := false) {
	_player_send(player, Command_Request_Status{check_cur_song})
}
player_request_queue :: proc(player: ^Base_Player) {
	_player_send(player, Command_Request_Queue{})
}
player_request_albums :: proc(player: ^Base_Player) {
	_player_send(player, Command_Request_Albums{})
}

player_request_cover :: proc(
	player: ^Base_Player,
	file: mpd.Song_File,
	album: mpd.Album_Name,
	size: Cover_Size,
) {
	alloc := player.allocator

	// TODO!: add a delay between cover requests after some number of requests
	// to not overload user's device too much when reqeuesting lots of covers.
	file := mpd.Song_File(strings.clone(string(file), alloc))
	key := cover_key_make_cloned(file, album, size, alloc)
	cmd := Command_Request_Cover{key, file, size, alloc}
	_player_send(player, cmd)
}

// Playback commands.

player_play_or_resume :: proc(player: ^Base_Player) {
	switch player.playstate {
	case .Play:
	case .Pause:
		_player_send(player, Command_Resume{})
	case .Stop:
		_player_send(player, Command_Play{})
	}
}
player_pause :: proc(player: ^Base_Player) {
	if player.playstate == .Play {
		_player_send(player, Command_Pause{})
	}
}
player_toggle_play :: proc(player: ^Base_Player) {
	if player.playstate == .Play {
		player_pause(player)
	} else {
		player_play_or_resume(player)
	}
}
player_next :: proc(player: ^Base_Player) {
	if player.cur_song == nil do return
	_player_send(player, Command_Next{})
}
player_previous :: proc(player: ^Base_Player) {
	if player.cur_song == nil do return
	_player_send(player, Command_Previous{})
}

player_seek :: proc(player: ^Base_Player, seconds: Seconds) {
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

	if player.playstate == .Stop {
		_player_send(player, Command_Play{})
		_player_send(player, Command_Seek{seconds})
		// FIXME!: `seek <index> <time>` doesn't seem to do anything?? Well done MPD.
		// `play` and `seekcur <time>` sequence also doesn't seem to work.
		// _command_send(player, Command_Seek_Song{index, seconds})
	} else {
		_player_send(player, Command_Seek{seconds})
	}
}

player_seek_percent :: proc(player: ^Base_Player, percent: f32) {
	secs := Seconds(percent) * player.duration
	player_seek(player, secs)
}

// Queue commands

cmd_make_load_album :: proc(player: ^Base_Player, name: mpd.Album_Name) -> Command_Load_Album {
	return {name = strings.clone(name, player.allocator), allocator = player.allocator}
}
player_load_album :: proc(player: ^Base_Player, name: mpd.Album_Name) {
	_player_send(player, cmd_make_load_album(player, name))
}

player_load_random_album :: proc(player: ^Base_Player) {
	if len(player._album_pool) == 0 do return

	drained := player._album_pool_drained
	if drained == 0 || drained >= len(player._album_pool) {
		rand.shuffle(player._album_pool[:])
		player._album_pool_drained = 0
	}

	index := player._album_pool[player._album_pool_drained]
	album := player.albums[index]
	player_load_album(player, mpd.album_name(album))

	player._album_pool_drained += 1
}

cmd_make_load_from_songs :: proc(player: ^Base_Player, songs: []mpd.Song) -> Command_Load {
	files := make([]mpd.Song_File, len(songs), player.allocator)
	for song, i in songs {
		file := strings.clone(string(song.file), player.allocator)
		files[i] = mpd.Song_File(file)
	}
	return Command_Load{files = files, allocator = player.allocator}
}

player_queue_play :: proc(player: ^Base_Player, index: mpd.Song_Index, force := false) {
	if !force && player.cur_song == index do return
	_player_send(player, Command_Queue_Play{index, 0})
}

cmd_make_queue_add :: proc(
	player: ^Base_Player,
	file: mpd.Song_File,
	index: mpd.Song_Index,
	play := false,
) -> Command_Queue_Add {
	file := strings.clone(string(file), player.allocator)
	return {mpd.Song_File(file), index, play, player.allocator}
}
player_queue_add :: proc(player: ^Base_Player, file: mpd.Song_File, index: mpd.Song_Index) {
	_player_send(player, cmd_make_queue_add(player, file, index))
}

player_queue_remove :: proc(player: ^Base_Player, index: mpd.Song_Index) {
	assert(0 <= index && int(index) < len(player.queue))
	_player_send(player, Command_Queue_Remove{index})
}

player_queue_reorder :: proc(player: ^Base_Player, from, to: mpd.Song_Index) {
	if from == to do return
	_player_send(player, Command_Queue_Reorder{from, to})
}

player_queue_shuffle :: proc(player: ^Base_Player) {
	if len(player.queue) <= 1 do return
	_player_send(player, Command_Queue_Shuffle{})
}

player_queue_clear :: proc(player: ^Base_Player) {
	if len(player.queue) == 0 do return
	_player_send(player, Command_Queue_Clear{})
}

// ------------------------------
// Handle.
// ------------------------------

_player_handle_command :: proc(
	shared: ^Player_Shared,
	client: ^mpd.Client,
	command: Player_Command,
) -> (
	err: mpd.Error,
) {
	switch cmd in command {
	case Command_Request_Status:
		status := mpd.request_status(client) or_return
		_response_send_status(shared.responses, status, cmd.check_cur_song)
		return nil

	case Command_Request_Queue:
		queue := mpd.request_queue(client, shared.allocator) or_return
		_response_send(shared.responses, Response_Queue{queue})
		return nil

	case Command_Request_Albums:
		attempts := 3
		albums: mpd.Album_List
		for len(albums) == 0 && attempts > 0 {
			albums = mpd.request_albums(client, shared.allocator) or_return
			attempts -= 1
		}
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

		// TODO: may be i should reuse a cover surface of the same album and of
		// the larger size, and down scale it instead of requesting a picture
		// data for every cover request?
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
		return mpd.send_and_forget(client, "next")
	case Command_Previous:
		return mpd.send_and_forget(client, "previous")
	case Command_Resume:
		return mpd.send_and_forget(client, "pause 0")
	case Command_Pause:
		return mpd.send_and_forget(client, "pause 1")
	case Command_Stop:
		return mpd.send_and_forget(client, "stop")
	case Command_Queue_Play:
		mpd.send_and_forget(client, "play", cmd.index) or_return
		if cmd.seek > 0 {
			mpd.send_and_forget(client, "seekcur", cmd.seek) or_return
		}
		return nil
	case Command_Seek:
		return mpd.send_and_forget(client, "seekcur", cmd.seconds)
	case Command_Queue_Reorder:
		mpd.send_and_forget(client, "move", cmd.from, cmd.to) or_return
		status := mpd.request_status(client) or_return
		_response_send_status(shared.responses, status, true)
		return nil
	case Command_Queue_Remove:
		mpd.send_and_forget(client, "delete", cmd.index) or_return
		status := mpd.request_status(client) or_return
		_response_send_status(shared.responses, status, true)
		return nil
	case Command_Queue_Shuffle:
		return mpd.send_and_forget(client, "shuffle")
	case Command_Queue_Clear:
		return mpd.send_and_forget(client, "clear")

	case Command_Load_Album:
		mpd.send_and_forget(client, "clear") or_return

		// Search for album songs and add them to the queue.
		c := mpd.cmd_begin("findadd", context.allocator)
		mpd.cmd_push_tag_filter(&c, "Album", cmd.name)
		mpd.cmd_send(client, &c) or_return
		mpd.recv_and_forget(client) or_return

		// Play the first song.
		return mpd.send_and_forget(client, "play")

	case Command_Queue_Add:
		c := mpd.cmd_begin("add", context.allocator)
		mpd.cmd_push_quoted(&c, string(cmd.file))
		mpd.cmd_push_int(&c, int(cmd.index))
		mpd.cmd_send(client, &c) or_return
		mpd.recv_and_forget(client) or_return

		if cmd.play {
			mpd.send_and_forget(client, "play", cmd.index) or_return
		}
		return nil

	case Command_Load:
		sb := strings.builder_make(context.allocator)
		defer strings.builder_destroy(&sb)

		strings.write_string(&sb, "command_list_begin\n")
		strings.write_string(&sb, "clear\n")
		for file in cmd.files {
			strings.write_string(&sb, "add ")
			mpd.write_quoted_string(&sb, string(file))
			strings.write_byte(&sb, '\n')
		}
		if index, ok := cmd.play.?; ok {
			strings.write_string(&sb, "play ")
			strings.write_int(&sb, int(index))
			strings.write_byte(&sb, '\n')
		}
		if cmd.seek > 0 {
			strings.write_string(&sb, "seekcur ")
			strings.write_f32(&sb, f32(cmd.seek), 'f')
			strings.write_byte(&sb, '\n')
		}
		strings.write_string(&sb, "command_list_end\n")

		str := strings.to_string(sb)
		mpd.send_string(client, str) or_return
		return mpd.recv_and_forget(client)

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

		defer _command_destroy(command)
		err := _player_handle_command(shared, client, command)
		if err != nil {
			// TODO: display errors to the user.
			log.errorf("Failed to handle command %v: %v", command, err)
		}
	}

	return false
}
