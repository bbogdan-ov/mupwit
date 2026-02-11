package mpd

import "core:log"

request_queue_song_by_id :: proc(client: ^Client, id: uint) -> (song: Maybe(Song), err: Error) {
	song, err = #force_inline _request_queue_song_by_id(client, id)
	if err != nil {
		log.error(client, "Failed to request queue song by id", err)
	}
	return
}

@(private)
_request_queue_song_by_id :: proc(client: ^Client, id: uint) -> (song: Maybe(Song), err: Error) {
	executef(client, "playlistid %d", id) or_return

	res := receive(client) or_return
	defer response_destroy(&res)

	song = response_next_song(client, &res) or_return

	return
}

request_queue_songs :: proc(client: ^Client, songs: ^[dynamic]Song) -> (err: Error) {
	err = #force_inline _request_queue_songs(client, songs)
	if err != nil {
		log.error("Failed to request list of queue songs:", err)
	}
	return
}

@(private)
_request_queue_songs :: proc(client: ^Client, songs: ^[dynamic]Song) -> (err: Error) {
	executef(client, "playlistinfo") or_return // request all songs info in the current queue (playlist)
	res := receive(client) or_return
	defer response_destroy(&res)

	for {
		maybe_song := response_next_song(client, &res) or_return
		song := maybe_song.? or_break

		append(songs, song)
	}

	return nil
}
