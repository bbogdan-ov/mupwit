package mupwit

import "core:sync/chan"
import "lib:mpd"

Response_Queue :: struct {
	list: mpd.Song_List,
}

Response :: union {
	mpd.Status,
	Response_Queue,
}

player_send_response :: proc(response: Response) {
	chan.send(state.player.responses, response)
}

_player_handle_response :: proc(response: Response) {
	player := &state.player

	switch res in response {
	case mpd.Status:
		_player_set_status(res)

	case Response_Queue:
		mpd.song_list_destroy(&player.queue)
		player.queue = res.list
	}
}
