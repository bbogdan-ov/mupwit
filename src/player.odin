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

	client, conn_err := mpd.connect()
	assert(conn_err == nil) // TODO: handle error.
	defer mpd.disconnect(&client)

	_stuff(&client)
}

_stuff :: proc(client: ^mpd.Client) -> (err: mpd.Error) {
	mpd.send(client, "idle") or_return

	s := mpd.recv_blocking(client) or_return
	defer delete(s)
	p := mpd.parser_make(s)

	changes, ok := mpd.parser_next_changes(&p)
	if !ok do return

	log.info(changes)

	return nil
}
