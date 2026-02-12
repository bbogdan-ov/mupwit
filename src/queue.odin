package mupwit

import "core:log"

import "../lib/mpd"

Queue :: struct {
	songs: [dynamic]mpd.Song,
}

queue: Queue

queue_init :: proc() {
	queue = Queue {
		songs = nil,
	}
}
queue_destroy :: proc() {
	_destroy_songs()
}

queue_on_queue :: proc(event: mpd.Event_Queue) {
	_destroy_songs()
	queue.songs = event.songs
	log.infof("Queue received %d songs", len(queue.songs))
}

@(private)
_destroy_songs :: #force_inline proc() {
	if queue.songs == nil do return

	for &song in queue.songs do mpd.song_destroy(&song)
	delete(queue.songs)
	queue.songs = nil
}
