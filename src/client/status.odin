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
		case "duration":
			secs := pair_parse_f32(pair) or_return
			status.duration = time.Duration(secs) * time.Second
		}
	}

	return
}
