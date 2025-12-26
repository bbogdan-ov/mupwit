package client

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

	// Id of the current song
	cur_song_id: int,

	// Time elapsed within the current song
	elapsed:     time.Duration,
	// Duration of the current song
	duration:    time.Duration,
}

request_status :: proc(client: ^Client) -> Error {
	return execute(client, "status")
}

receive_status :: proc(client: ^Client) -> (status: Status, err: Error) {
	pairs := receive_pairs(client) or_return
	defer pairs_destroy(pairs)

	state: Playstate = .Stop
	volume: int
	cur_song_id: int
	elapsed: time.Duration
	duration: time.Duration

	for pair in pairs.list {
		switch pair.name {
		case "state":
			switch pair.value {
			case "play":
				state = .Play
			case "pause":
				state = .Pause
			case "stop":
				state = .Stop
			}

		case "volume":
			volume = pair_parse_int(pair) or_return

		case "songid":
			cur_song_id = pair_parse_int(pair) or_return

		case "elapsed":
			secs := pair_parse_f32(pair) or_return
			elapsed = time.Duration(secs) * time.Second
		case "duration":
			secs := pair_parse_f32(pair) or_return
			duration = time.Duration(secs) * time.Second
		}
	}

	return Status{state, volume, cur_song_id, elapsed, duration}, nil
}
