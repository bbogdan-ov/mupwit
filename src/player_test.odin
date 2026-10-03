package mupwit

import "base:intrinsics"
import "base:runtime"
import "core:container/queue"
import "core:log"
import "core:math"
import "core:reflect"
import "core:slice"
import "core:testing"

import "lib:mpd"
import "lib:ui"

cont_queue :: queue

expect :: testing.expect
expect_eq :: testing.expect_value
temp_guard :: runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD

@(test)
test_player :: proc(t: ^testing.T) {
	// TODO!: test simultaneous sending of commands that depend on the current
	// state of the player and that modify this state when their responses wasn't
	// received "in time".
	// For example:
	// - Send "play an album".
	// - Send "play song at index 10".
	//   After loading an album, this song index may be invalidated (e.g. album
	//   simply has less songs). So this command should be skipped in this case.
	// - Just now received the updated queue. (e.g. may be because of a lag)
	//
	// Currently cases like this are not handled at all.

	test_commands(t)
	test_history(t)
}

// Test sequential command invoking (without sending a next command untill a
// response of a previous command has been received) and simulate "network
// delay" between command sending and receiving an updated state.
test_commands :: proc(t: ^testing.T) -> bool {
	log.infof("--- TEST: %v ---", #procedure)

	player := cast(^Test_Player)player_create_with(&TEST_PLAYER_VTABLE)
	defer player_destroy(player)
	player_connect(player)

	expect_eq(t, len(player.queue), 0)
	expect_eq(t, len(player.albums), 0)

	_player_handle_responses(player)

	expect_eq(t, len(player.queue), 12) or_return
	expect_eq(t, len(player.albums), 90) or_return
	check_undo_redo_count(t, player, 0, 0) or_return

	_player_send(player, Command_Queue_Remove{10})
	expect_eq(t, len(player.queue), 11) or_return // `Command_Queue_Remove` does an "optimistic update".
	_player_handle_responses(player)
	// TODO: check that the queue was not touched here at all even after a "queue" response.
	expect_eq(t, len(player.queue), 11) or_return

	_player_send(player, cmd_make_queue_add(player, "path/to/song.mp3", 9))
	expect_eq(t, len(player.queue), 11) or_return // No optimistic update.
	_player_handle_responses(player)
	expect_eq(t, len(player.queue), 12) or_return // Queue updates only after receiving an up-to-date queue from a server.

	expect_eq(t, player.elapsed, 0)
	_player_send(player, Command_Seek{123.45})
	expect_eq(t, player.elapsed, 123.45) or_return // Optimistic update.
	_player_handle_responses(player)
	expect_eq(t, player.elapsed, 123) or_return

	expect_eq(t, player.cur_song, nil)
	_player_send(player, Command_Queue_Play{4, 78.9}) // No optimistic update.
	expect_eq(t, player.cur_song, nil) or_return
	expect_eq(t, player.elapsed, 123) or_return
	_player_handle_responses(player)
	expect_eq(t, player.cur_song, 4) or_return
	expect_eq(t, player.elapsed, 78) or_return

	expect_eq(t, player.queue[2].title, "Fucked Up") or_return
	expect_eq(t, player.queue[3].title, "Hummingbird") or_return
	_player_send(player, Command_Queue_Reorder{2, 6}) // Optimistic update.
	expect_eq(t, len(player.queue), 12) or_return
	expect_eq(t, player.queue[2].title, "Hummingbird") or_return
	expect_eq(t, player.queue[6].title, "Fucked Up") or_return
	expect_eq(t, player.cur_song, 3) or_return // Also optimistically updates the current song index.
	_player_handle_responses(player)
	expect_eq(t, len(player.queue), 12) or_return
	expect_eq(t, player.queue[2].title, "Hummingbird") or_return
	expect_eq(t, player.queue[6].title, "Fucked Up") or_return
	expect_eq(t, player.cur_song, 3) or_return

	{
		album := player.albums[0]
		expect_eq(t, mpd.album_name(album), "0") // Album "0" by Low Roar
		expect_eq(t, len(album.songs), 13)

		cmd := cmd_make_load_from_songs(player, album.songs[:])
		cmd.play = 8
		cmd.seek = 456.78
		_player_send(player, cmd) // No optimistic update.
		expect_eq(t, len(player.queue), 12) or_return
		expect_eq(t, player.cur_song, 3) or_return
		expect_eq(t, player.elapsed, 78) or_return
		_player_handle_responses(player)
		expect_eq(t, len(player.queue), len(album.songs)) or_return
		expect_eq(t, player.cur_song, 8) or_return
		expect_eq(t, player.elapsed, 456) or_return

		expect_eq(t, player.queue[0].file, album.songs[0].file)
	}

	{
		_player_send(player, cmd_make_load_album(player, "Some album")) // No optimistic update.
		expect_eq(t, len(player.queue), 13) or_return
		_player_handle_responses(player)
		expect_eq(t, len(player.queue), 9) or_return

		first_song := player.queue[0]
		expect_eq(t, first_song.file, "Thom Yorke/ANIMA/001 Traffic.mp3")
		expect_eq(t, first_song.title, "Traffic")

		last_song := slice.last(player.queue[:])
		expect_eq(t, last_song.file, "Thom Yorke/ANIMA/009 Runwayaway.mp3")
		expect_eq(t, last_song.title, "Runwayaway")
	}

	_player_send(player, Command_Queue_Clear{}) // No optimistic update.
	expect_eq(t, len(player.queue), 9) or_return
	_player_handle_responses(player)
	expect_eq(t, len(player.queue), 0) or_return

	return true
}

// Test the player histroy and how some commands affect it like if the changes
// where made within the app. (e.g. a button was pressed to remove a song)
test_history :: proc(t: ^testing.T) -> bool {
	log.infof("--- TEST: %v ---", #procedure)

	player := player_create_with(&TEST_PLAYER_VTABLE)
	defer player_destroy(player)
	player_connect(player)

	expect_eq(t, len(player.queue), 0)
	_player_handle_responses(player)
	expect_eq(t, len(player.queue), 12)

	initial_queue := mpd.song_list_clone(player.queue[:], player.queue.allocator)
	defer mpd.song_list_destroy(&initial_queue)

	check_undo_redo_count(t, player, 0, 0) or_return

	// Remove first two songs.
	{
		_test_send_and_handle(player, Command_Queue_Remove{0})
		_test_send_and_handle(player, Command_Queue_Remove{1})
		expect_eq(t, len(player.queue), 10) or_return

		check_undo_redo_count(t, player, 2, 0) or_return
		check_undo(player, 0, Command_Queue_Add) or_return
		check_undo(player, 1, Command_Queue_Add) or_return
	}

	// Undo the latest remove, one of them is still in the history.
	{
		_test_undo_and_handle(player)
		expect_eq(t, len(player.queue), 11) or_return

		check_undo_redo_count(t, player, 1, 1) or_return
		check_undo(player, 0, Command_Queue_Add) or_return
		if cmd, ok := check_redo(player, 0, Command_Queue_Remove); ok {
			expect_eq(t, cmd.index, 1)
		}
	}

	// Play a song, but nothing will be saved into the history (it stays the
	// same), because there is no current song yet.
	{
		_test_send_and_handle(player, Command_Queue_Play{5, Seconds(123)})
		check_undo_redo_count(t, player, 1, 1) or_return
	}

	// Now we have a current song and this "play" command invoking will change
	// the history.
	{
		_test_send_and_handle(player, Command_Queue_Play{8, 0})

		check_undo_redo_count(t, player, 2, 0) or_return
		check_undo(player, 0, Command_Queue_Add) or_return
		if cmd, ok := check_undo(player, 1, Command_Queue_Play); ok {
			expect_eq(t, cmd.index, 5)
			expect_eq(t, cmd.seek, 123)
		}
	}

	{
		_test_undo_and_handle(player)
		_test_undo_and_handle(player)

		check_undo_redo_count(t, player, 0, 2) or_return
		check_redo(player, 0, Command_Queue_Play) or_return
		check_redo(player, 1, Command_Queue_Remove) or_return
	}

	{
		_test_redo_and_handle(player)

		check_undo_redo_count(t, player, 1, 1) or_return
		check_undo(player, 0, Command_Queue_Add) or_return
		check_redo(player, 0, Command_Queue_Play) or_return
	}

	{
		_test_send_and_handle(player, Command_Seek{89})

		check_undo_redo_count(t, player, 2, 0) or_return
		check_undo(player, 0, Command_Queue_Add)
		if cmd, ok := check_undo(player, 1, Command_Seek); ok {
			expect_eq(t, cmd.seconds, 123)
		}
	}

	{
		for _ in 0 ..< 4 {
			_test_undo_and_handle(player)
			_test_redo_and_handle(player)
		}
		check_undo_redo_count(t, player, 2, 0) or_return
	}

	{
		_test_undo_and_handle(player)
		_test_undo_and_handle(player)
		check_undo_redo_count(t, player, 0, 2) or_return
		expect_eq(t, len(player.queue), len(initial_queue)) or_return
	}

	// "Remove, reorder, undo, undo" for each song in the queue.
	// After the loop the queue should go back to the same state as before.
	for i in 0 ..< len(player.queue) {
		temp_guard()

		song_index := mpd.Song_Index(i)

		removed_song := mpd.song_clone(player.queue[song_index], context.temp_allocator)
		_test_send_and_handle(player, Command_Queue_Remove{song_index})
		expect_eq(t, len(player.queue), 11) or_return

		from, to := max(song_index - 1, 0), mpd.Song_Index(0)
		_test_send_and_handle(player, Command_Queue_Reorder{from, to})

		check_undo_redo_count(t, player, 2, 0) or_return
		if cmd, ok := check_undo(player, 0, Command_Queue_Add); ok {
			expect_eq(t, cmd.file, removed_song.file) or_return
		}
		if cmd, ok := check_undo(player, 1, Command_Queue_Reorder); ok {
			expect_eq(t, cmd.from, to) or_return
			expect_eq(t, cmd.to, from) or_return
		}

		_test_undo_and_handle(player)
		_test_undo_and_handle(player)
		expect_eq(t, len(player.queue), 12) or_return

		check_undo_redo_count(t, player, 0, 2) or_return
		if cmd, ok := check_redo(player, 0, Command_Queue_Reorder); ok {
			expect_eq(t, cmd.from, from) or_return
			expect_eq(t, cmd.to, to) or_return
		}
		if cmd, ok := check_redo(player, 1, Command_Queue_Remove); ok {
			expect_eq(t, cmd.index, song_index) or_return
		}
	}

	// Check if the queue is still the same after all the manipulations.
	for i in 0 ..< len(player.queue) {
		a := &player.queue[i]
		b := &initial_queue[i]
		if a.file != b.file {
			log.errorf(
				"unexpected queue song at #%v/%v: %q != %q",
				i,
				len(player.queue),
				a.file,
				b.file,
			)
			return false
		}
	}

	return true
}

// ------------------------------
// Utils.
// ------------------------------

check_undo_redo_count :: proc(
	t: ^testing.T,
	player: ^Base_Player,
	undos, redos: int,
	loc := #caller_location,
) -> bool {
	expect_eq(t, player_undo_count(player), undos, loc) or_return
	expect_eq(t, player_redo_count(player), redos, loc) or_return
	return true
}

check_undo :: proc(
	player: ^Base_Player,
	nth: int,
	$T: typeid,
	loc := #caller_location,
) -> (
	cmd: T,
	ok: bool,
) {
	undo := queue.get(&player.history.undo, nth)
	#partial switch c in undo.command {
	case T:
		return c, true
	case:
		name := intrinsics.type_canonical_name(T)
		var := reflect.union_variant_typeid(undo.command)
		log.errorf("expected undo[%v] to be %v, but got %v", nth, name, var, location = loc)
		return {}, false
	}
}

check_redo :: proc(
	player: ^Base_Player,
	nth: int,
	$T: typeid,
	loc := #caller_location,
) -> (
	cmd: T,
	ok: bool,
) {
	undo := queue.get(&player.history.redo, nth)
	#partial switch c in undo.command {
	case T:
		return c, true
	case:
		name := intrinsics.type_canonical_name(T)
		var := reflect.union_variant_typeid(undo.command)
		log.errorf("expected redo[%v] to be %v, but got %v", nth, name, var, location = loc)
		return {}, false
	}
}

// ------------------------------
// Player methods.
// ------------------------------

Test_Player :: struct {
	using base:   Base_Player,
	responses:    cont_queue.Queue(Player_Response),

	// "Fake server" state and the source of truth.
	_fake_queue:  mpd.Song_List,
	_fake_albums: mpd.Album_List,
	_fake_status: mpd.Status,
}

@(rodata)
TEST_PLAYER_VTABLE := Player_VTable {
	create        = _test_player_create,
	connect       = _test_player_connect,
	destroy       = _test_player_destroy,
	send_command  = _test_player_send_command,
	recv_response = _test_player_recv_response,
}

_test_send_and_handle :: proc(
	player: ^Base_Player,
	command: Player_Command,
	loc := #caller_location,
) {
	_player_send(player, command, loc)
	_player_handle_responses(player, loc)
}
_test_undo_and_handle :: proc(player: ^Base_Player, loc := #caller_location) {
	player_undo(player)
	_player_handle_responses(player, loc)
}
_test_redo_and_handle :: proc(player: ^Base_Player, loc := #caller_location) {
	player_redo(player)
	_player_handle_responses(player, loc)
}

_test_player_create :: proc(allocator: runtime.Allocator, loc: Source_Loc) -> ^Base_Player {
	player := new(Test_Player, allocator, loc)
	player.vtable = &TEST_PLAYER_VTABLE
	player.allocator = allocator
	return player
}
_test_player_connect :: proc(player: rawptr, loc: Source_Loc) {
	player := cast(^Test_Player)player

	// Populate the state of the "fake server".
	parser := mpd.parser_make(#load("test/queue.txt"))
	player._fake_queue = mpd.parser_next_song_list(&parser, player.allocator, loc)

	parser = mpd.parser_make(#load("test/songs.txt"))
	player._fake_albums = mpd.parser_next_album_list(&parser, player.allocator, loc)

	player._fake_status.volume = 100
	player._fake_status.queue_version = 1
}
_test_player_destroy :: proc(player: rawptr, loc: Source_Loc) {
	player := cast(^Test_Player)player

	for res in queue.pop_back_safe(&player.responses) {
		_response_destroy(res)
	}
	queue.destroy(&player.responses)

	mpd.song_list_destroy(&player._fake_queue)
	mpd.album_list_destroy(player._fake_albums)
}

_test_send_response :: proc(player: ^Test_Player, response: Player_Response) {
	queue.push_back(&player.responses, response)
}
_test_send_queue :: proc(player: ^Test_Player) {
	queue := mpd.song_list_clone(player._fake_queue[:], player._fake_queue.allocator)
	_test_send_response(player, Response_Queue{queue})
}
_fake_status_set_cur_song :: proc(player: ^Test_Player, index: mpd.Song_Index) {
	player._fake_status.cur_song_index = max(index, 0)
	player._fake_status.cur_song_id = mpd.Song_Id(index + 1)
}

_test_player_send_command :: proc(player: rawptr, command: Player_Command, loc: Source_Loc) {
	player := cast(^Test_Player)player

	// This function simulates behavior of a MPD server. It should NOT directly
	// modify the state of the player, instead, it should send a new player
	// state using `_test_send_response`.

	#partial switch cmd in command {
	case Command_Request_Status:
		_test_send_response(player, player._fake_status)

	case Command_Request_Queue:
		_test_send_queue(player)

	case Command_Request_Albums:
		albums := mpd.album_list_clone(player._fake_albums[:], player._fake_albums.allocator)
		_test_send_response(player, albums)

	case Command_Queue_Add:
		// NOTE: for now only song files are known.
		song: mpd.Song
		song.file = cmd.file
		song.allocator = cmd.allocator
		inject_at(&player._fake_queue, cmd.index, song)

		_test_send_queue(player)

	case Command_Queue_Remove:
		mpd.song_destroy(player._fake_queue[cmd.index])
		ordered_remove(&player._fake_queue, cmd.index)

		_test_send_queue(player)

	case Command_Queue_Play:
		player._fake_status.playstate = .Play
		_fake_status_set_cur_song(player, cmd.index)
		player._fake_status.elapsed = mpd.Seconds(math.floor(cmd.seek)) // `floor` to simulate float error.
		player._fake_status.duration = 300
		_test_send_response(player, player._fake_status)

	case Command_Seek:
		player._fake_status.elapsed = mpd.Seconds(math.floor(cmd.seconds))
		_test_send_response(player, player._fake_status)

	case Command_Queue_Reorder:
		ui.slice_reorder(player._fake_queue[:], int(cmd.from), int(cmd.to))

		index := ui.shifted_index(player._fake_status.cur_song_index, cmd.from, cmd.to)
		_fake_status_set_cur_song(player, index)

		_test_send_queue(player)
		_test_send_response(player, player._fake_status)

	case Command_Queue_Clear:
		mpd.song_list_clear(&player._fake_queue)
		_test_send_queue(player)

	case Command_Load_Album:
		parser := mpd.parser_make(#load("test/album.txt"))
		mpd.song_list_destroy(&player._fake_queue)
		player._fake_queue = mpd.parser_next_song_list(&parser, player.allocator, loc)

		player._fake_status.elapsed = 0
		_fake_status_set_cur_song(player, 0)

		_test_send_queue(player)
		_test_send_response(player, player._fake_status)

		// Ignore the `cmd.name`.
		_command_destroy(command)

	case Command_Load:
		mpd.song_list_destroy(&player._fake_queue)
		player._fake_queue = make(mpd.Song_List, len(cmd.files), player.allocator)

		for file, i in cmd.files {
			song: mpd.Song
			song.file = file
			song.allocator = cmd.allocator
			player._fake_queue[i] = song
		}

		_fake_status_set_cur_song(player, cmd.play.? or_else 0)
		player._fake_status.elapsed = mpd.Seconds(math.floor(f32(cmd.seek)))

		_test_send_queue(player)
		_test_send_response(player, player._fake_status)

		delete(cmd.files, cmd.allocator)

	case Command_Disconnect:

	case:
		log.warnf("TEST PLAYER: Unhandled command: %v", command)
		_command_destroy(command)
	}
}

_test_player_recv_response :: proc(
	player: rawptr,
	loc: Source_Loc,
) -> (
	res: Player_Response,
	ok: bool,
) {
	player := cast(^Test_Player)player
	return queue.pop_front_safe(&player.responses)
}
