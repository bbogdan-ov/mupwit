package mpd

import "core:log"
import "core:strings"
import "core:time"

Playstate :: enum {
	Stop = 0,
	Play,
	Pause,
}

Status :: struct {
	state:       Playstate,

	// Volume in range 0..=100
	volume:      uint,

	// Id of the currently playing song
	cur_song_id: Maybe(uint),

	// Time elapsed within the current song
	elapsed:     time.Duration,
	// Duration of the current song
	duration:    time.Duration,
}

Song :: struct {
	// Song file uri
	uri:      string,
	id:       int,
	title:    Maybe(string),
	artist:   Maybe(string),
	album:    Maybe(string),
	duration: time.Duration,
}

song_destroy :: proc(song: ^Song) {
	assert(song != nil)

	delete(song.uri)
	delete(song.title.? or_else "")
	delete(song.artist.? or_else "")
	delete(song.album.? or_else "")
}

@(require_results)
request_status :: proc(client: ^Client, loc := #caller_location) -> (err: Error) {
	status: Status
	status, err = #force_inline _request_status(client)
	if err != nil {
		log.error("CLIENT: Failed to request current playback status:", err)
	}

	if status.cur_song_id == client.prev_song_id {
		// Song didn't change, simply send the up-to-date playback status.
		_send_event(client, Event_Status{status})
		return
	}

	// Song did change, request its info
	song: Maybe(Song) = nil

	client.prev_song_id = status.cur_song_id

	if id, ok := status.cur_song_id.?; ok {
		song, err = request_queue_song_by_id(client, id)
		if err != nil {
			log.error(
				"CLIENT: Failed to request the current song after the status has changed:",
				err,
			)
			return
		}
	}

	_send_event(client, Event_Status_And_Song{status, song})
	return
}

@(private, require_results)
_request_status :: proc(client: ^Client) -> (status: Status, err: Error) {
	executef(client, "status") or_return

	// Receive status data
	res := receive(client) or_return
	defer response_destroy(&res)

	for {
		maybe_pair := response_next_pair(&res) or_return
		pair := maybe_pair.? or_break

		switch pair.name {
		case "state":
			switch pair.value {
			case "play":
				status.state = .Play
			case "pause":
				status.state = .Pause
			case "stop":
				status.state = .Stop
			}

		case "volume":
			status.volume = uint(pair_parse_int(pair) or_return)

		case "songid":
			status.cur_song_id = uint(pair_parse_int(pair) or_return)

		case "elapsed":
			secs := pair_parse_f32(pair) or_return
			status.elapsed = time.Duration(secs) * time.Second
		}
	}

	return
}

// Parse the next song info the `Response`
// All song fields are owned by this struct, don't forget to `song_destroy`
@(require_results)
response_next_song :: proc(client: ^Client, res: ^Response) -> (song: Maybe(Song), err: Error) {
	song, err = _response_next_song(res)
	if err != nil {
		log.error("CLIENT: Failed to parse next song from the response:", err)
	}
	return
}

@(private, require_results)
_response_next_song :: proc(res: ^Response) -> (song: Maybe(Song), err: Error) {
	s: Song
	s.id = -1

	already_parsed := false
	pairs: for {
		prev_offset := res.offset
		maybe_pair := response_next_pair(res) or_return
		pair := maybe_pair.? or_break

		// NOTE: ignore other pairs because we don't care.
		switch pair.name {
		case "file":
			if already_parsed {
				// A new song info has began
				res.offset = prev_offset
				break pairs
			}

			s.uri = strings.clone(pair.value)
			already_parsed = true
		case "Title":
			s.title = strings.clone(pair.value)
		case "Artist":
			s.artist = strings.clone(pair.value)
		case "Album":
			s.album = strings.clone(pair.value)
		case "duration":
			secs := pair_parse_f32(pair) or_return
			s.duration = time.Duration(secs) * time.Second
		case "Id":
			s.id = pair_parse_int(pair) or_return
		}
	}

	if len(s.uri) > 0 {
		if s.id < 0 {
			log.errorf("CLIENT: Found a song with no id (%d) '%s'", s.id, s.uri)
		}

		return s, nil
	} else {
		return nil, nil
	}
}
