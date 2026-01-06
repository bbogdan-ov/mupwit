package mpd

import "base:runtime"
import "core:fmt"
import "core:net"
import "core:strings"
import "core:thread"
import "core:time"
import "vendor:raylib"

import "../mpsc"

DEFAULT_IP: string : "127.0.0.1"
// MPD uses this port by default
DEFAULT_PORT: int : 6600

Error_Kind :: enum {
	None = 0,
	Mpd_Error,
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
_Connect_Data :: struct {
	client: ^Client,
	ip:     string,
	port:   int,
}

State :: enum {
	Connecting,
	Ready,
	Error,
}

Client :: struct {
	sock:              net.TCP_Socket,
	events:            mpsc.Queue(Event),
	actions:           mpsc.Queue(Action),
	// Current error message.
	// It may be set by a function that returned `mpd.Error`.
	// Should be a static string.
	error_msg:         Maybe(string),
	// Location where the `error_msg` was set.
	error_loc:         runtime.Source_Code_Location,
	// Id of the previous currently playing song.
	// Used to check whether the current song has changed.
	prev_song_id:      Maybe(uint),
	events_arena:      runtime.Arena,
	actions_arena:     runtime.Arena,
	events_allocator:  runtime.Allocator,
	actions_allocator: runtime.Allocator,
}

// Open a connection with the MPD server
connect :: proc(ip := DEFAULT_IP, port := DEFAULT_PORT) -> ^Client {
	client := new(Client)

	client.events_allocator = runtime.arena_allocator(&client.events_arena)
	client.actions_allocator = runtime.arena_allocator(&client.actions_arena)

	mpsc.init(&client.events)
	mpsc.init(&client.actions)

	data := new(_Connect_Data)
	data.client = client
	data.ip = ip
	data.port = port

	t := thread.create(_do_connect)
	t.data = data
	thread.start(t)

	return client
}

destroy :: proc(client: ^Client) {
	free_all(client.events_allocator)
	free_all(client.actions_allocator)
	free(client)
}

@(private)
_do_connect :: proc(t: ^thread.Thread) {
	data := (^_Connect_Data)(t.data)

	err := _dial(data)
	if err != nil {
		_push_event(data.client, Event_State_Changed{.Error})
	}
}

@(private)
_dial :: proc(data: ^_Connect_Data) -> Error {
	addr, ok := net.parse_ip4_address(data.ip)
	if !ok do return .Parse_IP

	client := data.client
	client.sock = net.dial_tcp(addr, data.port) or_return

	// Consume the MPD version message
	{
		res := receive(client) or_return
		response_next_string(&res)
		response_destroy(&res)
	}

	// Successfully connected
	_push_event(client, Event_State_Changed{.Ready})
	trace(.INFO, "Successfully connected")

	start := time.now()

	STATUS_FETCH_INTERVAL: time.Duration : 250 * time.Millisecond
	status_fetch_timer := time.Duration(0)

	// Loop forever
	for {
		elapsed := time.since(start)

		status_fetch_timer -= elapsed

		// Fetch current status and song periodically
		if status_fetch_timer <= 0 {
			_fetch_status(client)
			status_fetch_timer = STATUS_FETCH_INTERVAL
		}

		action: for {
			switch a in _pop_action(client) {
			case nil:
				break action
			case Action:
				err := _handle_action(client, a)
				trace_error(client, err)
			}
		}

		start = time.now()
		time.sleep(30 * time.Millisecond)
	}

	return nil
}

@(private)
_fetch_status :: proc(client: ^Client) {
	status, err := request_status(client)
	if err != nil {
		trace_error(client, err)
		return
	}

	if status.cur_song_id == client.prev_song_id {
		// Song didn't change, simply send the up-to-date playback status
		_push_event(client, Event_Status{status})
		return
	}

	// Song did change, request its info
	song: Maybe(Song) = nil

	if id, ok := status.cur_song_id.?; ok {
		song, err = request_queue_song_by_id(client, id)
		if err != nil {
			trace_error(client, err)
			return
		}
	}

	_push_event(client, Event_Status_And_Song{status, song})

	client.prev_song_id = status.cur_song_id
}

@(private)
_handle_action :: proc(client: ^Client, action: Action) -> Error {
	switch a in action {
	case Action_Play:
		executef(client, "pause 0") or_return
		receive_ok(client) or_return
	case Action_Pause:
		executef(client, "pause 1") or_return
		receive_ok(client) or_return

	case Action_Req_Cover:
		cover := request_cover(client, a.song_uri) or_return
		_push_event(client, Event_Cover{a.id, cover})

	case Action_Req_Albums:
		albums := make([dynamic]Album, len = 0, cap = 20)
		request_albums(client, &albums) or_return
		_push_event(client, Event_Albums{albums})
	}

	return nil
}

@(private)
_push_event :: proc(client: ^Client, event: Event) {
	node := new(mpsc.Node(Event), allocator = client.events_allocator)
	node.value = event
	mpsc.push(&client.events, node)
}
pop_event :: proc(client: ^Client) -> Event {
	state, node := mpsc.poll(&client.events)
	if state == .Item {
		assert(node != nil)
		return node.value // copy the event
	}
	return nil
}
free_events :: proc(client: ^Client) {
	free_all(client.events_allocator)
}

push_action :: proc(client: ^Client, action: Action) {
	node := new(mpsc.Node(Action), allocator = client.actions_allocator)
	node.value = action
	mpsc.push(&client.actions, node)
}
@(private)
_pop_action :: proc(client: ^Client) -> Maybe(Action) {
	state, node := mpsc.poll(&client.actions)
	if state == .Item {
		assert(node != nil)
		return node.value // copy the action
	}
	return nil
}
@(private)
_free_actions :: proc(client: ^Client) {
	free_all(client.actions_allocator)
}

set_error :: proc(client: ^Client, msg: string, loc := #caller_location) {
	client.error_msg = msg
	client.error_loc = loc
}

trace_error :: proc(client: ^Client, error: Error) {
	if error == nil do return

	sb := strings.builder_make()

	fmt.sbprint(&sb, "CLIENT: ")

	// Prepend error message if any
	if msg, ok := client.error_msg.?; ok {
		fmt.sbprintf(&sb, "%s %s: ", client.error_loc, msg)
		client.error_msg = nil
	}

	switch e in error {
	case Error_Kind:
		switch e {
		case .None:
		case .Mpd_Error:
			fmt.sbprint(&sb, "MPD error")
		case .Parse_IP:
			fmt.sbprint(&sb, "Failed to parse IP")
		case .Cmd_Invalid_Size:
			fmt.sbprint(&sb, "COMMAND: Sent invalid number of bytes")
		case .Response_Not_OK:
			fmt.sbprint(&sb, "RESPONSE: Received response is not OK")
		case .Response_Expected_String:
			fmt.sbprint(&sb, "RESPONSE: Expected a valid UTF-8 string")
		case .Response_Invalid_Pair:
			fmt.sbprint(&sb, "RESPONSE: Invalid pair")
		case .Response_Unexpected_Binary_Size:
			fmt.sbprint(&sb, "RESPONSE: Binary response differs from the expected size")
		case .Response_Expected_Song_Info:
			fmt.sbprint(&sb, "RESPONSE: Expected song info")
		case .Pair_Expected_Number:
			fmt.sbprint(&sb, "RESPONSE: Pair value expected to be a number")
		case .Unexpected_Pair:
			fmt.sbprint(&sb, "RESPONSE: Unexpected pair")
		case .End_Of_Response:
			fmt.sbprint(&sb, "RESPONSE: Unexpected end of response")
		}
	case net.Network_Error:
		fmt.sbprintf(&sb, "Network error: %s", e)
	}

	raylib.TraceLog(.ERROR, strings.to_cstring(&sb))
}

trace :: proc(level: raylib.TraceLogLevel, msg: string, args: ..any) {
	sb := strings.builder_make()
	fmt.sbprint(&sb, "CLIENT: ")
	fmt.sbprintf(&sb, msg, ..args)
	raylib.TraceLog(level, strings.to_cstring(&sb))
}
