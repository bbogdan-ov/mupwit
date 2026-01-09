package mupwit

import "mpd"

Player :: struct #all_or_none {
	// Current playback status
	status: Maybe(mpd.Status),
	// Current song
	song:   Maybe(mpd.Song),
}

player_make :: proc() -> Player {
	return Player{status = nil, song = nil}
}
player_destroy :: proc(player: ^Player) {
	if s, ok := &player.song.?; ok do mpd.song_destroy(s)
}

player_on_status :: proc(player: ^Player, status: mpd.Status) {
	player.status = status
}
player_on_status_and_song :: proc(player: ^Player, status: mpd.Status, song: Maybe(mpd.Song)) {
	player.status = status

	s, ok := &player.song.?
	if ok do mpd.song_destroy(s)
	player.song = song
}
