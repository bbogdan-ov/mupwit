package mupwit

import "base:runtime"
import "core:sync/chan"
import "lib:cairo"
import "lib:mpd"

Response_Status :: struct #all_or_none {
	status:         mpd.Status,
	// Whether upon receiving this response should check for whether the
	// current song has been changed.
	check_cur_song: bool,
}

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

Response_Connected :: struct {}

Response_Error :: struct {
	error: mpd.Error,
}

Player_Response :: union {
	mpd.Album_List,
	Response_Status,
	Response_Queue,
	Response_Cover,
	Response_Connected,
	Response_Error,
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
_response_send_status :: proc(ch: Responses_Chan, status: mpd.Status, check_cur_song := false) {
	_response_send(ch, Response_Status{status, check_cur_song})
}

_player_handle_responses :: proc(player: ^Base_Player, loc := #caller_location) {
	for response in player->_recv_response(loc) {
		_player_handle_response(player, response)
	}
}

_player_handle_response :: proc(player: ^Base_Player, response: Player_Response) {
	switch res in response {
	case mpd.Album_List:
		_player_set_albums(player, res)

	case Response_Status:
		_player_set_status(player, res.status, res.check_cur_song)

	case Response_Queue:
		_player_set_queue(player, res.list)

	case Response_Cover:
		_player_handle_cover_response(player, res)
		cover_key_delete(res.key, res.allocator)

	case Response_Connected:
		// TODO: should also send a `Response_Disconnected` upon disconnecting
		// from a server. Currently you can only disconnect when closing the
		// app, so this response is useless for now.
		player.state = .Connected

	case Response_Error:
		player_push_event(player, Event_Error{res.error})
		player.state = .Disconnected
	}
}
