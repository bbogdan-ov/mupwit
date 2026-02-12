package mpd

import "core:log"

@(require_results)
request_queue_song_by_id :: proc(client: ^Client, id: uint) -> (song: Maybe(Song), err: Error) {
	song, err = #force_inline _request_queue_song_by_id(client, id)
	if err != nil {
		log.error(client, "CLIENT: Failed to request queue song by id", err)
	}
	return
}

@(private, require_results)
_request_queue_song_by_id :: proc(client: ^Client, id: uint) -> (song: Maybe(Song), err: Error) {
	executef(client, "playlistid %d", id) or_return

	res := receive(client) or_return
	defer response_destroy(&res)

	song = response_next_song(client, &res) or_return

	return
}

@(require_results)
request_queue_songs :: proc(client: ^Client) -> (err: Error) {
	err = #force_inline _request_queue_songs(client)
	if err != nil {
		log.error("CLIENT: Failed to request list of queue songs:", err)
	}
	return
}

@(private, require_results)
_request_queue_songs :: proc(client: ^Client) -> (err: Error) {
	executef(client, "playlistinfo") or_return // request all songs info in the current queue (playlist)
	res := receive(client) or_return
	defer response_destroy(&res)

	songs := make([dynamic]Song, len = 0, cap = 256)

	for {
		maybe_song := response_next_song(client, &res) or_return
		song := maybe_song.? or_break

		append(&songs, song)
	}

	_send_event(client, Event_Queue{songs})
	return nil
}
