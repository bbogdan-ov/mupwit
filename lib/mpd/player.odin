#+vet explicit-allocators

// NOTE: do not rename enum variants, they are the same (except the casing) as
// MPD's "enums" (e.g. play state) for simpler deserialization.

package mpd

import "base:intrinsics"

// Unique song ID within queue.
// This ID is only used within a queue, therefore it is only assigned after
// adding a song to the queue.
// Filename (URI) of the song should act as a unique "global" ID.
Song_Id :: distinct int

// Position of a song in queue or album.
Song_Pos :: distinct int

// Song file path relative to the MPD music dir.
Song_File :: distinct string

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
	volume:           int,
	// Wheter to keep repeating the queue.
	repeat:           bool,
	// Whether queue is shuffled.
	random:           bool,
	// When enabled, playback is stopped after current song, or song is
	// repeated if the `repeat` mode is enabled.
	single:           Single_State,
	// When enabled, each song played is removed from queue.
	consume:          Single_State,
	// Number of songs in queue.
	queue_count:      int `playlistlength`,
	playstate:        Play_State `state`,
	cur_song_number:  Song_Pos `song`,
	cur_song_id:      Song_Id `songid`,
	next_song_number: Song_Pos `nextsong`,
	next_song_id:     Song_Id `nextsongid`,
	// Time elapsed within currently playing song.
	elapsed:          Seconds,
	// Duration of currently playing song.
	duration:         Seconds,
	error:            string,
}

Song_Info :: struct {
	file:         Song_File,
	artist:       string `Artist`,
	album_artist: string `AlbumArtist`,
	title:        string `Title`,
	album:        string `Album`,
	release_date: string `Date`,
	genre:        string `Genre`, // TODO: this should be an array.
	id:           Song_Id `Id`,
	number:       Song_Pos `Track`, // Number of track in its album.
	disc:         int `Disc`,
	duration:     Seconds,
	queue_pos:    Song_Pos `Pos`,
}

song_info_strings_len :: proc(info: ^Song_Info) -> (n: int) {
	n += len(info.file) + len(info.artist)
	n += len(info.album_artist) + len(info.title)
	n += len(info.album) + len(info.release_date) + len(info.genre)
	return n
}
