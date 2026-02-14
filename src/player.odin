package mupwit

import "../lib/mpd"
import "core:log"
import "core:time"

Player :: struct #all_or_none {
	// Current playback status
	status:         Maybe(mpd.Status),
	// Current song
	song:           Maybe(mpd.Song),

	// Songs in the current queue.
	queue:          [dynamic]mpd.Song,
	// Time elapsed within the whole queue.
	// Currently playing song doesn't count.
	queue_elapsed:  time.Duration,
	// Duration of the whole queue.
	queue_duration: time.Duration,
}

player: Player

player_init :: proc() {
	player = Player {
		status         = nil,
		song           = nil,
		queue          = nil,
		queue_elapsed  = 0,
		queue_duration = 0,
	}
}
player_destroy :: proc() {
	if s, ok := &player.song.?; ok do mpd.song_destroy(s)

	if player.queue != nil {
		_destroy_queue()
		delete(player.queue)
		player.queue = nil
	}
}

player_on_status :: proc(event: mpd.Event_Status) {
	player.status = event.status
}
player_on_status_and_song :: proc(event: mpd.Event_Status_And_Song) {
	player.status = event.status

	_update_queue_elapsed()

	s, ok := &player.song.?
	if ok do mpd.song_destroy(s)
	player.song = event.song
}
player_on_queue :: proc(event: mpd.Event_Queue) {
	_destroy_queue()

	player.queue = event.songs
	_update_queue_duration()
	_update_queue_elapsed()

	log.infof("Queue received %d songs", len(player.queue))
}

@(private)
_update_queue_duration :: proc() {
	player.queue_duration = 0
	for song in player.queue {
		player.queue_duration += song.duration
	}
}

@(private)
_update_queue_elapsed :: proc() {
	player.queue_elapsed = 0

	cur_song_id, ok := player_cur_song_id()
	if !ok do return

	for song in player.queue {
		if song.id == cur_song_id do break
		player.queue_elapsed += song.duration
	}
}

@(private)
_destroy_queue :: #force_inline proc() {
	for &song in player.queue do mpd.song_destroy(&song)
	clear(&player.queue)
}

player_cur_song_id :: #force_inline proc() -> (id: uint, ok: bool) {
	status: mpd.Status

	status = player.status.? or_return
	id = status.cur_song_id.? or_return
	return id, true
}
