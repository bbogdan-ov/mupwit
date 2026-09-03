#+vet explicit-allocators

package mupwit

import "core:strings"
import "lib:mpd"

Song_Id :: mpd.Song_Id
Song_Pos :: mpd.Song_Pos
Song_File :: mpd.Song_File
Play_State :: mpd.Play_State

Player :: struct {
	client:    mpd.Client,
	playstate: Play_State,
	cur_song:  Maybe(Song_Pos),
	queue:     [dynamic]Song,
}

Song :: struct #all_or_none {
	file:         Song_File,
	artist:       string,
	album_artist: string,
	title:        string,
	album:        string,
	release_date: string,
	genre:        string,
	id:           Song_Id, // ID within current queue.
	number:       Song_Pos,
	disc:         int,
	duration:     Seconds,

	// All strings in this struct will slice themselves from this buffer.
	_string_pool: strings.Builder,
}

player_connect :: proc() {
	p := &state.player

	err: mpd.Error
	p.client, err = mpd.connect(context.allocator)
	assert(err == nil) // TODO: handle error.c:W

	_ = player_request_status()
	_ = player_request_queue()
}

player_destroy :: proc() {
	player := &state.player

	mpd.disconnect(&player.client)

	player_clear_queue()
	delete(player.queue)
}

song_make_from_info :: proc(info: ^mpd.Song_Info, allocator := context.allocator) -> Song {
	cap := mpd.song_info_strings_len(info)
	string_pool := strings.builder_make_len_cap(0, cap, allocator)

	_put :: proc(pool: ^strings.Builder, s: $T) -> T {
		start := len(pool.buf)
		strings.write_string(pool, string(s))
		end := len(pool.buf)
		return T(pool.buf[start:end])
	}

	pool := &string_pool
	
	// odinfmt:disable
	return Song{
		file         = _put(pool, info.file),
		artist       = _put(pool, info.artist),
		album_artist = _put(pool, info.album_artist),
		title        = _put(pool, info.title),
		album        = _put(pool, info.album),
		release_date = _put(pool, info.release_date),
		genre        = _put(pool, info.genre),
		id           = info.id,
		number       = info.number,
		disc         = info.disc,
		duration     = info.duration,
		_string_pool = string_pool,
	}
	// odinfmt:enable
}

song_destroy :: proc(song: ^Song) {
	strings.builder_destroy(&song._string_pool)
}

@(require_results)
player_request_status :: proc() -> (ok: bool) {
	player := &state.player

	_send("status") or_return
	s := _recv_blocking(context.allocator) or_return
	defer delete(s, context.allocator)

	p := mpd.parser_make(s)
	status := mpd.parser_next_struct(mpd.Status, &p) or_return

	player.playstate = status.playstate

	return true
}

@(require_results)
player_request_queue :: proc() -> (ok: bool) {
	player := &state.player

	_send("playlistid") or_return
	s := _recv_blocking(context.allocator) or_return
	defer delete(s, context.allocator)

	// TODO!: should not rebuild the whole queue, should only replace songs
	// that has been changed.
	player_clear_queue()

	p := mpd.parser_make(s)
	for info in mpd.parser_next_struct(mpd.Song_Info, &p) {
		info := info
		song := song_make_from_info(&info, context.allocator)
		append(&player.queue, song)
	}

	return true
}

player_clear_queue :: proc() {
	player := &state.player

	for &song in player.queue do song_destroy(&song)
	clear(&player.queue)
}

@(require_results)
_send :: proc($format: string, args: ..any, loc := #caller_location) -> (ok: bool) {
	err := mpd.send(&state.player.client, format, ..args, loc = loc)
	return err == nil
}

_recv_blocking :: proc(
	allocator := context.allocator,
	loc := #caller_location,
) -> (
	str: string,
	ok: bool,
) {
	s, err := mpd.recv_blocking(&state.player.client, allocator, loc)
	return s, err == nil
}
