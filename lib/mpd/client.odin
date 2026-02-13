package mpd

import "base:runtime"
import "core:log"
import "core:net"
import "core:strings"
import "core:sync/chan"
import "core:thread"
import "core:time"

DEFAULT_IP: string : "127.0.0.1"
// MPD uses this port by default
DEFAULT_PORT: int : 6600

Error_Kind :: enum {
	None = 0,
	Mpd_Error,
	Invalid_Mpd_Version_Msg,
	Parse_IP,
	Cmd_Invalid_Size,
	Response_Not_OK,
	Response_Expected_String,
	Response_Invalid_Pair,
	Response_Unexpected_Binary_Size,
	Response_Expected_Song_Info,
	Pair_Expected_Number,
	Unexpected_Pair,
	End_Of_Response,
}

Error :: union #shared_nil {
	Error_Kind,
	net.Network_Error,
}

@(private)
_Connect_Data :: struct #all_or_none {
	client: ^Client,
	ip:     string,
	port:   int,
	logger: log.Logger,
}

State :: enum {
	Connecting,
	Ready,
	Error,
}

Client :: struct {
	sock:         net.TCP_Socket,
	events:       chan.Chan(Event),
	actions:      chan.Chan(Action),
	// Id of the previous currently playing song.
	// Used to check whether the current song has changed.
	prev_song_id: Maybe(uint),
	thread:       ^thread.Thread,
}

// Open a connection with the MPD server
connect :: proc(ip := DEFAULT_IP, port := DEFAULT_PORT) -> ^Client {
	client := new(Client)

	err: runtime.Allocator_Error
	client.events, err = chan.create_buffered(chan.Chan(Event), 16, context.allocator)
	assert(err == nil)
	client.actions, err = chan.create_buffered(chan.Chan(Action), 16, context.allocator)
	assert(err == nil)

	data := new(_Connect_Data)
	data^ = _Connect_Data {
		client = client,
		ip     = ip,
		port   = port,
		logger = context.logger,
	}

	client.thread = thread.create(_do_connect)
	client.thread.data = data
	thread.start(client.thread)

	return client
}

// Carefuly close the connection and free the memory owned by the client.
close :: proc(client: ^Client) {
	send_action(client, Action_Close{})

	thread.destroy(client.thread)
	log.info("CLIENT: Connection closed, destroying the client")

	chan.destroy(client.events)
	chan.destroy(client.actions)
	free(client)
}

@(private)
_do_connect :: proc(t: ^thread.Thread) {
	data := (^_Connect_Data)(t.data)
	defer free(data)

	context.logger = data.logger

	err := _dial(data)
	if err != nil {
		_send_event(data.client, Event_State_Changed{.Error})
	}
}

@(private, require_results)
_dial :: proc(data: ^_Connect_Data) -> (err: Error) {
	addr, ok := net.parse_ip4_address(data.ip)
	if !ok do return .Parse_IP

	client := data.client
	client.sock = net.dial_tcp(addr, data.port) or_return

	_consume_version_message(client) or_return

	// Successfully connected
	_send_event(client, Event_State_Changed{.Ready})
	log.info("CLIENT: Successfully connected")

	start := time.now()

	STATUS_REQ_INTERVAL: time.Duration : 250 * time.Millisecond
	status_req_timer := time.Duration(0)

	// Loop forever
	loop: for {
		elapsed := time.since(start)

		status_req_timer -= elapsed

		err := _handle_idle(client)
		if err != nil {
			log.error("CLIENT: Failed to handle idle event:", err)
		}

		// Request current status and song periodically
		if status_req_timer <= 0 {
			err := request_status(client)
			if err != nil {
				log.error("CLIENT: Failed to request current status after interval:", err)
			}
			status_req_timer = STATUS_REQ_INTERVAL
		}

		// Drain and handle all queued actions.
		action: for {
			switch a in _recv_action(client) {
			case nil:
				break action
			case Action:
				close, _ := _handle_action(client, a) // NOTE: ignoring the error
				if close do break loop
			}
		}

		start = time.now()
		time.sleep(30 * time.Millisecond)
	}

	log.info("CLIENT: Closing the connection...")
	net.close(client.sock)

	return nil
}

// Handle MPD "idle" events.
// See: https://mpd.readthedocs.io/en/latest/protocol.html#command-idle
@(private, require_results)
_handle_idle :: proc(client: ^Client) -> (err: Error) {
	// FIXME: i'm not sure if this is a good way to listen to idle events...
	executef(client, "idle") or_return
	// Send "noidle" immediately because "idle" is a blocking command, "noidle"
	// makes it stop listening to events and sends all the occurred events back.
	executef(client, "noidle") or_return

	res := receive(client) or_return
	defer response_destroy(&res)

	for {
		maybe_pair := response_next_pair(&res) or_return
		pair := maybe_pair.? or_break

		if pair.name != "changed" {
			log.errorf("CLIENT: Invalid idle event pair: %s => '%s'", pair.name, pair.value)
			return .Response_Invalid_Pair
		}

		log.debugf("CLIENT: Received idle event: '%s'", pair.value)

		err: Error = nil
		switch pair.value {
		case "database":
			err = request_albums(client)
		case "playlist":
			err = request_queue_songs(client)
		case "player":
			err = request_status(client)
		case: // ignore
		}

		if err != nil {
			log.errorf("CLIENT: Failed to make request after '%s' idle event: %s", pair.value, err)
		}
	}


	return nil
}

@(private, require_results)
_consume_version_message :: proc(client: ^Client) -> (err: Error) {
	res := receive(client) or_return
	defer response_destroy(&res)

	msg: string
	msg, err = response_next_line(&res)

	// TODO!: save this message somewhere to show to the user later.
	if err != nil {
		log.error("CLIENT: Expected MPD version message but got error:", err)
		return err
	} else if !strings.starts_with(msg, "OK MPD ") {
		log.errorf("CLIENT: Received an invalid MPD version message: '%s'", msg)
		return .Invalid_Mpd_Version_Msg
	}

	log.infof("CLIENT: Received MPD version message: '%s'", msg)
	return
}

@(private, require_results)
_handle_action :: proc(client: ^Client, action: Action) -> (close: bool, err: Error) {
	switch a in action {
	case Action_Play:
		executef(client, "pause 0") or_return
		receive_ok(client) or_return
	case Action_Pause:
		executef(client, "pause 1") or_return
		receive_ok(client) or_return
	case Action_Toggle:
		executef(client, "pause") or_return
		receive_ok(client) or_return

	case Action_Req_Cover:
		cover := request_cover(client, a.song_uri) or_return
		_send_event(client, Event_Cover{a.id, cover})

	case Action_Req_Albums:
		request_albums(client) or_return
	case Action_Req_Queue:
		request_queue_songs(client) or_return

	case Action_Close:
		close = true
	}

	return
}

@(private)
_send_event :: proc(client: ^Client, event: Event) {
	ok := chan.send(client.events, event)
	assert(ok)
}
recv_event :: proc(client: ^Client) -> Event {
	event, ok := chan.try_recv(client.events)
	if !ok do return nil
	return event
}

send_action :: proc(client: ^Client, action: Action) {
	ok := chan.send(client.actions, action)
	assert(ok)
}
@(private)
_recv_action :: proc(client: ^Client) -> Maybe(Action) {
	action, ok := chan.try_recv(client.actions)
	if !ok do return nil
	return action
}
