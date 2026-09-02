#+vet explicit-allocators

package mpd

import "core:strings"

_ :: strings

// Position of a song in queue.
Song_Pos :: distinct int
Song_Id :: distinct int

Seconds :: distinct f32

// Playback state.
Playstate :: enum u8 {
	Stop = 0,
	Pause,
	Play,
}

Single_State :: enum u8 {
	No = 0,
	Yes,
	// I think it means that the current song will be replayed only once or
	// only one song will be consumed for `single` and `consume` status fields
	// respectively.
	// It seems that there is no documentation for this value yet.
	Oneshot,
}

// Player status.
Status :: struct {
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
	queue_len:        int `playlistlength`,
	state:            Playstate,
	cur_song_number:  Song_Pos `song`,
	cur_song_id:      Song_Id `songid`,
	next_song_number: Song_Pos `nextsong`,
	next_song_id:     Song_Id `nextsongid`,
	// Time elapsed within currently playing song.
	elapsed:          Seconds,
	// Duration of currently playing song.
	duration:         Seconds,

	// TODO: may be also include the `error` field.
}
