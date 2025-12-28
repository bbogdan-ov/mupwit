package client

request_queue_song_by_id :: proc(client: ^Client, id: int) -> (song: Song, err: Error) {
	song, err = #force_inline _request_queue_song_by_id(client, id)
	if err != nil {
		client.error_msg = "Unable to request a song by id from the queue"
	}
	return
}

@(private)
_request_queue_song_by_id :: proc(client: ^Client, id: int) -> (song: Song, err: Error) {
	execute(client, "playlistid", id) or_return

	res := receive(client) or_return
	song = response_next_song(client, &res) or_return

	return
}
