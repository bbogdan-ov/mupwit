package client

import "core:net"
import "core:time"

Status :: struct {
	// Volume in range 0..=100
	volume:       int,

	// Index of the current song in the current queue
	cur_song_pos: int,
	// Id of the current song
	cur_song_id:  int,

	// Time elapsed within the current song
	elapsed:      time.Duration,
	// Duration of the current song
	duration:     time.Duration,
}

status_request :: proc(sock: net.TCP_Socket) -> Error {
	return cmd_immediate(sock, "status")
}

status_receive :: proc(sock: net.TCP_Socket) -> (status: Status, err: Error) {
	pairs := pairs_receive(sock) or_return
	defer pairs_destroy(pairs)

	for pair in pairs.list {
		switch pair.name {
		case "volume":
			status.volume = pair_parse_int(pair) or_return

		case "song":
			status.cur_song_pos = pair_parse_int(pair) or_return
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

	return status, nil
}
