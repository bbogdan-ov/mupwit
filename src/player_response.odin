package mupwit

import "base:runtime"
import "core:sync/chan"
import "lib:mpd"

Response_Queue :: struct #all_or_none {
	list:   mpd.Song_List,
	status: mpd.Status,
}

Response_Cover :: struct #all_or_none {
	key:       Cover_Key,
	size:      Cover_Size,
	surface:   Maybe(Cover_Surface),
	color:     Color,
	allocator: runtime.Allocator,
}

Response :: union {
	mpd.Status,
	mpd.Album_List,
	Response_Queue,
	Response_Cover,
}

_response_destroy :: proc(response: Response) {
	#partial switch res in response {
	case Response_Cover:
		delete(string(res.key), res.allocator)
	}
}

_response_send :: proc(ch: Responses_Chan, response: Response) {
	chan.send(ch, response)
}

_player_handle_response :: proc(player: ^Player, response: Response) {
	defer _response_destroy(response)

	switch res in response {
	case mpd.Status:
		_player_set_status(player, res)

	case mpd.Album_List:
		_player_set_albums(player, res)

	case Response_Queue:
		_player_set_queue(player, res.list)
		_player_set_status(player, res.status)

	case Response_Cover:
		_player_handle_cover_response(player, res)
	}
}
