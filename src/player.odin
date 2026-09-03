package mupwit

import "core:log"
import "core:thread"
import "core:time"
import "lib:mpd"

connect :: proc() {
	state.client_thread = thread.create(_do_connect)
	thread.start(state.client_thread)
}

_do_connect :: proc(t: ^thread.Thread) {
	context.logger = make_logger()

	client, err := mpd.connect()
	assert(err == nil) // TODO: handle error.
	defer mpd.disconnect(&client)

	should_send := true
	for {
		s, received := mpd.recv(&client) or_break
		if received {
			log.infof("Received: %q", s)
			delete(s)
			should_send = true
		} else {
			log.info("Waiting...")
		}

		if should_send {
			log.info("Idle")
			mpd.send(&client, "idle") or_break
			should_send = false
		}

		time.sleep(1 * time.Second)
	}
}
