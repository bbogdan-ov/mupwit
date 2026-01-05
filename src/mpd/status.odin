package mpd

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
	volume:      int,

	// Id of the currently playing song
	cur_song_id: Maybe(int),

	// Time elapsed within the current song
	elapsed:     time.Duration,
	// Duration of the current song
	duration:    time.Duration,
}

Song :: struct {
	id:       int,
	file:     string,
	title:    Maybe(string),
	artist:   Maybe(string),
	album:    Maybe(string),
	duration: time.Duration,
}

song_destroy :: proc(song: ^Song) {
	if song == nil do return

	delete(song.file)
	delete(song.title.? or_else "")
	delete(song.artist.? or_else "")
	delete(song.album.? or_else "")
}

request_status :: proc(client: ^Client) -> (status: Status, err: Error) {
	status, err = #force_inline _request_status(client)
	if err != nil {
		client.error_msg = "Unable to request current playback status"
	}
	return
}

@(private)
_request_status :: proc(client: ^Client) -> (status: Status, err: Error) {
	execute(client, "status") or_return

	// Receive status data
	res := receive(client) or_return
	defer response_destroy(&res)

	for {
		pair, err := response_next_pair(&res)
		if err == .End_Of_Response do break
		else if err != nil do return Status{}, err

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
			status.volume = pair_parse_int(pair) or_return

		case "songid":
			status.cur_song_id = pair_parse_int(pair) or_return

		case "elapsed":
			secs := pair_parse_f32(pair) or_return
			status.elapsed = time.Duration(secs) * time.Second
		}
	}

	return
}

// Parse the next song info the `Response`
response_next_song :: proc(client: ^Client, res: ^Response) -> (song: Song, err: Error) {
	song, err = _response_next_song(res)
	if err != nil {
		client.error_msg = "Unable to parse the next song from the response"
	}
	return
}

@(private)
_response_next_song :: proc(res: ^Response) -> (song: Song, err: Error) {
	for {
		pair, err := response_next_pair(res)
		if err == .End_Of_Response do break
		else if err != nil do return Song{}, err

		switch pair.name {
		case "file":
			song.file = strings.clone(pair.value)
		case "Title":
			song.title = strings.clone(pair.value)
		case "Artist":
			song.artist = strings.clone(pair.value)
		case "Album":
			song.album = strings.clone(pair.value)
		case "duration":
			secs := pair_parse_f32(pair) or_return
			song.duration = time.Duration(secs) * time.Second
		}
	}

	return
}
