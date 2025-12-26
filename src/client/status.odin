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

request_status :: proc(client: ^Client) -> (status: Status, err: Error) {
	execute(client, "status") or_return

	// Receive status data
	res := receive(client) or_return
	defer response_destroy(&res)

	state: Playstate = .Stop
	volume: int
	cur_song_id: int
	elapsed: time.Duration
	duration: time.Duration

	for {
		maybe_pair := response_next_pair(&res) or_return
		pair := maybe_pair.? or_break

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
