package client

import "core:fmt"
import "core:net"
import "core:strings"
import "core:thread"
import "core:time"
import "vendor:raylib"

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
	Pair_Expected_Number,
	Unexpected_Pair,
	End_Of_Response,
}

Error :: union #shared_nil {
	Error_Kind,
	net.Network_Error,
}

@(private)
Connect_Data :: struct {
	event_loop: ^Event_Loop,
	ip:         string,
	port:       int,
}

State :: enum {
	Connecting,
	Ready,
	Error,
}

Client :: struct {
	sock:      net.TCP_Socket,
	error_msg: Maybe(string),
}

// Open a connection with the MPD server
connect :: proc(loop: ^Event_Loop, ip := DEFAULT_IP, port := DEFAULT_PORT) {

	data := new(Connect_Data)
	data.event_loop = loop
	data.ip = ip
	data.port = port

	t := thread.create(do_connect)
	t.data = data
	thread.start(t)
}

@(private)
do_connect :: proc(t: ^thread.Thread) {
	data := (^Connect_Data)(t.data)

	err := dial(data)
	if err != nil {
		loop_push_event(data.event_loop, Event_State_Changed{.Error})
	}
}

@(private)
dial :: proc(data: ^Connect_Data) -> Error {
	addr, ok := net.parse_ip4_address(data.ip)
	if !ok do return .Parse_IP

	time.sleep(1 * time.Second)

	sock := net.dial_tcp(addr, data.port) or_return
	client := Client {
		sock      = sock,
		error_msg = nil,
	}

	// Consume the MPD version message
	res := receive(&client) or_return
	response_next_string(&res)

	// Successfully connected
	loop_push_event(data.event_loop, Event_State_Changed{.Ready})
	trace(.INFO, "Successfully connected")

	// Loop forever
	for {
		action: for {
			switch a in loop_pop_action(data.event_loop) {
			case nil:
				break action
			case Action:
				err := handle_action(&client, data.event_loop, a)
				trace_error(&client, err)
			}
		}

		time.sleep(30 * time.Millisecond)
	}

	return nil
}

@(private)
handle_action :: proc(client: ^Client, event_loop: ^Event_Loop, action: Action) -> Error {
	switch a in action {
	case Action_Play:
		execute(client, "pause 0") or_return
		receive_ok(client) or_return
	case Action_Pause:
		execute(client, "pause 1") or_return
		receive_ok(client) or_return

	case Action_Req_Status:
		status := request_status(client) or_return
		loop_push_event(event_loop, Event_Status{status})

	case Action_Req_Song_And_Status:
		status := request_status(client) or_return
		song := request_queue_song_by_id(client, status.cur_song_id.? or_else -1) or_return

		loop_push_event(event_loop, Event_Song_And_Status{song, status})

	case Action_Req_Queue_Song:
		song := request_queue_song_by_id(client, a.id) or_return
		loop_push_event(event_loop, Event_Song{song})

	case Action_Req_Cover:
		cover := request_cover(client, a.song_uri) or_return
		loop_push_event(event_loop, Event_Cover{cover})
	}

	return nil
}

trace_error :: proc(client: ^Client, error: Error) {
	if error == nil do return

	sb := strings.builder_make()

	fmt.sbprint(&sb, "CLIENT: ")

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

	// Append error message if any
	#partial switch msg in client.error_msg {
	case string:
		fmt.sbprintf(&sb, ": %s", msg)
		clear_error(client)
	}

	raylib.TraceLog(.ERROR, strings.to_cstring(&sb))
}

clear_error :: proc(client: ^Client) {
	#partial switch msg in client.error_msg {
	case string:
		delete(msg)
		client.error_msg = nil
	}
}

trace :: proc(level: raylib.TraceLogLevel, msg: string, args: ..any) {
	sb := strings.builder_make()
	fmt.sbprint(&sb, "CLIENT: ")
	fmt.sbprintf(&sb, msg, ..args)
	raylib.TraceLog(level, strings.to_cstring(&sb))
}
