#+vet explicit-allocators

// NOTE: do not rename enum variants, they are the same (except the casing) as
// MPD's "enums" (e.g. play state) for simpler deserialization.

package mpd

import "base:intrinsics"
import "base:runtime"
import "core:fmt"
import "core:io"
import "core:strings"

// Unique song ID within queue.
// This ID is only used within a queue, therefore it is only assigned after
// adding a song to the queue.
// Filename (URI) of the song should act as a unique "global" ID.
Song_Id :: distinct int

// Position of a song in queue or album.
// Often referred as "SONGPOS" in the MPD protocol.
Song_Index :: distinct int

// Song file path relative to the MPD music dir.
Song_File :: distinct string

Song_Title :: string
Artist_Name :: string
Album_Name :: string

Seconds :: distinct f32

// Playback state.
Play_State :: enum u8 {
	Stop = 0,
	Pause,
	Play,
}

// Single or consume state.
Single_State :: enum u8 {
	Off = 0,
	On,
	// I think it means that the current song will be replayed only once or
	// only one song will be consumed for `single` and `consume` status fields
	// respectively.
	// It seems that there is no documentation for this value yet.
	Oneshot,
}

// See `idle` command docs for more info:
//     https://mpd.readthedocs.io/en/stable/protocol.html
Change :: enum u16 {
	Database,
	Update,
	Stored_Playlist,
	Playlist,
	Player,
	Mixer,
	Output,
	Options,
	Partition,
	Sticker,
	Subscription,
	Message,
	Neighbor,
	Mount,
}
Changes :: bit_set[Change;u16]

// Player status.
Status :: struct {
	// Volume in range 0..=100
	volume:          int,
	// Whether to keep repeating the queue.
	repeat:          bool,
	// Whether queue is shuffled.
	random:          bool,
	// When enabled, playback is stopped after the current song, or song is
	// repeated if the `repeat` mode is enabled.
	single:          Single_State,
	// When enabled, each song played is removed from the queue.
	consume:         Single_State,
	// Version ID of the current queue, changes whenever the queue changes.
	queue_version:   int `playlist`,
	// Number of songs in the queue.
	queue_count:     int `playlistlength`,
	playstate:       Play_State `state`,
	cur_song_index:  Song_Index `song`,
	cur_song_id:     Song_Id `songid`,
	next_song_index: Song_Index `nextsong`,
	next_song_id:    Song_Id `nextsongid`,
	// Time elapsed within the currently playing song.
	elapsed:         Seconds,
	// Duration of the currently playing song.
	duration:        Seconds,
}

Song :: struct {
	file:         Song_File,
	artist:       Artist_Name `Artist`,
	title:        Song_Title `Title`,
	album:        Album_Name `Album`,
	date:         string `Date`,
	genre:        string `Genre`, // TODO: this should be an array.
	duration_str: string, // Pre-formatted duration in human-readable format.
	index:        Song_Index `Track`,
	disc:         int `Disc`,
	duration:     Seconds,

	// Queue-local data, if not in a queue, those fields are zeroed.
	queue_id:     Song_Id `Id`, // Song ID within current queue.

	// Allocator used to allocate strings.
	allocator:    runtime.Allocator,
}

Song_List :: distinct [dynamic]Song

song_clone :: proc(song: Song, allocator := context.allocator) -> Song {
	sclone :: strings.clone

	s := song
	s.allocator = allocator
	s.file = Song_File(sclone(string(song.file), s.allocator))
	s.artist = sclone(song.artist, s.allocator)
	s.title = sclone(song.title, s.allocator)
	s.album = sclone(song.album, s.allocator)
	s.date = sclone(song.date, s.allocator)
	s.genre = sclone(song.genre, s.allocator)
	s.duration_str = sclone(song.duration_str, s.allocator)
	return s
}

song_destroy :: proc(song: Song) {
	delete(string(song.file), song.allocator)
	delete(song.artist, song.allocator)
	delete(song.title, song.allocator)
	delete(song.album, song.allocator)
	delete(song.date, song.allocator)
	delete(song.genre, song.allocator)
	delete(song.duration_str, song.allocator)
}

// Destroy all songs inside a list and `clear()` it.
song_list_clear :: proc(list: ^Song_List) {
	for song in list do song_destroy(song)
	clear(list)
}

song_list_destroy :: proc(list: ^Song_List) {
	song_list_clear(list)
	delete(list^)
}

song_lists_differ :: proc(a, b: Song_List) -> bool {
	if len(a) != len(b) do return true

	for i in 0 ..< len(a) {
		if a[i].queue_id != b[i].queue_id {
			return true
		}
	}

	return false
}

Album :: struct {
	songs: Song_List,
}

Album_List :: distinct [dynamic]Album

album_name :: proc(album: Album) -> Album_Name #no_bounds_check {
	assert(len(album.songs) > 0)
	return album.songs[0].album
}
album_artist :: proc(album: Album) -> Album_Name #no_bounds_check {
	assert(len(album.songs) > 0)
	return album.songs[0].artist
}
album_first_song :: proc(album: Album) -> ^Song #no_bounds_check {
	assert(len(album.songs) > 0)
	return &album.songs[0]
}

album_destroy :: proc(album: ^Album) {
	song_list_destroy(&album.songs)
	album.songs = nil
}

album_list_destroy :: proc(list: Album_List) {
	for &album in list do album_destroy(&album)
	delete(list)
}

Picture :: struct {
	data_size: int `size`,
	mimetype:  string `type`,
	data:      []u8,
	allocator: runtime.Allocator,
}

picture_destroy :: proc(picture: Picture) {
	delete(picture.data, picture.allocator)
	delete(picture.mimetype, picture.allocator)
}

@(init, private)
_init_seconds_formatter :: proc "contextless" () {
	context = runtime.default_context()

	formatter :: proc(fi: ^fmt.Info, arg: any, verb: rune) -> bool {
		secs := arg.(Seconds) or_return

		neg := secs < 0
		d := abs(int(secs))
		if neg do io.write_byte(fi.writer, '-')
		if d < 60 {
			fmt.wprintf(fi.writer, "00:%02d", d)
		} else if d < 60 * 60 {
			fmt.wprintf(fi.writer, "%02d:%02d", d / 60, d % 60)
		} else {
			hours := d / 60 / 60
			mins := d / 60 % 60
			secs := d % 60
			fmt.wprintf(fi.writer, "%02d:%02d:%02d", hours, mins, secs)
		}
		return true
	}

	if fmt._user_formatters == nil {
		@(static) formatters: map[typeid]fmt.User_Formatter
		formatters = make(map[typeid]fmt.User_Formatter, context.allocator)
		fmt.set_user_formatters(&formatters)
	}
	fmt.register_user_formatter(Seconds, formatter)
}
