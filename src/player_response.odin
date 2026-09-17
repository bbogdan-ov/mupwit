package mupwit

import "core:sync/chan"
import "lib:mpd"

Response_Queue :: struct #all_or_none {
	list:   mpd.Song_List,
	status: mpd.Status,
}

Response :: union {
	mpd.Status,
	Response_Queue,
}

player_send_response :: proc(response: Response) {
	chan.send(state.player.responses, response)
}

_player_handle_response :: proc(response: Response) {
	response := response
	player := &state.player

	switch &res in response {
	case mpd.Status:
		_player_set_status(res)

	case Response_Queue:
		_player_set_status(res.status)

		if player.ignore_next_queue_response {
			player.ignore_next_queue_response = false
			if !mpd.song_lists_differ(player.queue, res.list) {
				mpd.song_list_destroy(&res.list)
				break
			}
		}

		mpd.song_list_destroy(&player.queue)
		player.queue = res.list

		on_received_queue(res.list)
	}
}
