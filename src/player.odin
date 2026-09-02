package mupwit

import "core:log"
import "core:thread"
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

	err = mpd.send(&client, "status")
	if err != nil do return

	p: mpd.Parser
	p, err = mpd.recv_and_parse(&client)
	if err != nil do return
	defer mpd.parser_destroy(p)

	state, _ := mpd.parser_next_named_pair(&p, "state")
	log.info("State:", state)
}
