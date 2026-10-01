package mupwit

import "base:runtime"
import "core:sync/chan"
import "lib:cairo"
import "lib:mpd"

Response_Queue :: struct #all_or_none {
	list: mpd.Song_List,
}

Response_Cover :: struct #all_or_none {
	key:       Cover_Key,
	size:      Cover_Size,
	surface:   Maybe(Cover_Surface),
	color:     Color,
	allocator: runtime.Allocator,
}

Player_Response :: union {
	mpd.Status,
	mpd.Album_List,
	Response_Queue,
	Response_Cover,
}

_response_destroy :: proc(response: Player_Response) {
	response := response

	#partial switch &res in response {
	case mpd.Album_List:
		mpd.album_list_destroy(res)
	case Response_Queue:
		mpd.song_list_destroy(&res.list)
	case Response_Cover:
		cover_key_delete(res.key, res.allocator)
		if surface, ok := res.surface.?; ok {
			cairo.surface_destroy(surface)
		}
	}
}

_response_send :: proc(ch: Responses_Chan, response: Player_Response) {
	chan.send(ch, response)
}

_player_handle_responses :: proc(player: ^Base_Player, loc := #caller_location) {
	for response in player.vtable.recv_response(player, loc) {
		_player_handle_response(player, response)
	}
}

_player_handle_response :: proc(player: ^Base_Player, response: Player_Response) {
	switch res in response {
	case mpd.Status:
		_player_set_status(player, res)

	case mpd.Album_List:
		_player_set_albums(player, res)

	case Response_Queue:
		_player_set_queue(player, res.list)

	case Response_Cover:
		_player_handle_cover_response(player, res)
		cover_key_delete(res.key, res.allocator)
	}
}
