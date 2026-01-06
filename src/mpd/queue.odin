package mpd

request_queue_song_by_id :: proc(client: ^Client, id: uint) -> (song: Maybe(Song), err: Error) {
	song, err = #force_inline _request_queue_song_by_id(client, id)
	if err != nil {
		set_error(client, "Unable to request a song by id from the queue")
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
