package mupwit

import "core:log"
import "core:time"

import "../lib/mpd"

Queue :: struct #all_or_none {
	songs:    [dynamic]mpd.Song,
	// Time elapsed within the whole queue.
	// Currently playing song doesn't count.
	elapsed:  time.Duration,
	// Duration of the whole queue.
	duration: time.Duration,
}

queue: Queue

queue_init :: proc() {
	queue = Queue {
		songs    = nil,
		elapsed  = 0,
		duration = 0,
	}
}
queue_destroy :: proc() {
	if queue.songs == nil do return

	_destroy_songs()
	delete(queue.songs)
	queue.songs = nil
}

queue_on_queue :: proc(event: mpd.Event_Queue) {
	_destroy_songs()

	queue.songs = event.songs
	_update_duration()
	_update_elapsed()

	log.infof("Queue received %d songs", len(queue.songs))
}
queue_on_status_and_song :: proc() {
	_update_elapsed()
}

@(private)
_update_duration :: proc() {
	queue.duration = 0
	for song in queue.songs {
		queue.duration += song.duration
	}
}

@(private)
_update_elapsed :: proc() {
	queue.elapsed = 0

	cur_song_id, ok := player.status.?.cur_song_id.?
	if !ok do return

	for song in queue.songs {
		if song.id == cur_song_id do break
		queue.elapsed += song.duration
	}
}

@(private)
_destroy_songs :: #force_inline proc() {
	for &song in queue.songs do mpd.song_destroy(&song)
	clear(&queue.songs)
}
