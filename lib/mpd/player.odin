#+vet explicit-allocators

// NOTE: do not rename enum variants, they are the same (except the casing) as
// MPD's "enums" (e.g. play state) for simpler deserialization.

package mpd

import "base:intrinsics"
import "base:runtime"

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
	// Wheter to keep repeating the queue.
	repeat:          bool,
	// Whether queue is shuffled.
	random:          bool,
	// When enabled, playback is stopped after current song, or song is
	// repeated if the `repeat` mode is enabled.
	single:          Single_State,
	// When enabled, each song played is removed from queue.
	consume:         Single_State,
	// Number of songs in queue.
	queue_count:     int `playlistlength`,
	playstate:       Play_State `state`,
	cur_song_index:  Song_Index `song`,
	cur_song_id:     Song_Id `songid`,
	next_song_index: Song_Index `nextsong`,
	next_song_id:    Song_Id `nextsongid`,
	// Time elapsed within currently playing song.
	elapsed:         Seconds,
	// Duration of currently playing song.
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

song_destroy :: proc(song: Song, loc := #caller_location) {
	delete(string(song.file), song.allocator, loc)
	delete(song.artist, song.allocator, loc)
	delete(song.title, song.allocator, loc)
	delete(song.album, song.allocator, loc)
	delete(song.date, song.allocator, loc)
	delete(song.genre, song.allocator, loc)
	delete(song.duration_str, song.allocator, loc)
}

// Destroy all songs inside a list and `clear()` it.
song_list_clear :: proc(list: ^Song_List, loc := #caller_location) {
	for song in list do song_destroy(song, loc)
	clear(list)
}

song_list_destroy :: proc(list: ^Song_List, loc := #caller_location) {
	song_list_clear(list, loc)
	delete(list^, loc)
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
