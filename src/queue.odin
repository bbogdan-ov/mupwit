package mupwit

import "core:log"
import "mpd"

Queue :: struct {
	songs: [dynamic]mpd.Song,
}

queue_make :: proc() -> Queue {
	return Queue{songs = nil}
}
queue_destroy :: proc(queue: ^Queue) {
	_queue_destroy_songs(queue)
}

queue_on_queue :: proc(queue: ^Queue, event: mpd.Event_Queue) {
	_queue_destroy_songs(queue)
	queue.songs = event.songs
	log.infof("Queue received %d songs", len(queue.songs))
}

@(private)
_queue_destroy_songs :: #force_inline proc(queue: ^Queue) {
	if queue.songs == nil do return

	for &song in queue.songs do mpd.song_destroy(&song)
	delete(queue.songs)
	queue.songs = nil
}
