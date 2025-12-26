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
	Parse_IP,
	Cmd_Invalid_Size,
	Response_Not_OK,
	Response_Expected_String,
	Response_Invalid_Pair,
	Respose_Pair_Expected_Number,
}

Error :: union #shared_nil {
	Error_Kind,
	net.Network_Error,
}

@(private)
Connect_Data :: struct {
	event_loop: ^Event_Loop,
	addr:       net.IP4_Address,
	port:       int,
}

State :: enum {
	Connecting,
	Ready,
	Error,
}

Client :: struct {
	sock: net.TCP_Socket,
}

// Open a connection with the MPD server
connect :: proc(loop: ^Event_Loop, ip := DEFAULT_IP, port := DEFAULT_PORT) -> Error {
	addr, ok := net.parse_ip4_address(ip)
	if !ok do return .Parse_IP

	data := new(Connect_Data)
	data.event_loop = loop
	data.addr = addr
	data.port = port

	t := thread.create(do_connect)
	t.data = data
	thread.start(t)

	return nil
}

@(private)
do_connect :: proc(t: ^thread.Thread) {
	data := (^Connect_Data)(t.data)

	time.sleep(1 * time.Second)

	sock, err := net.dial_tcp(data.addr, data.port)
	if err != nil {
		trace(.ERROR, "Unable to connect to the server: %s", err)

		loop_push_event(data.event_loop, Event_State_Changed{.Error})
		return
	}

	client := Client {
		sock = sock,
	}

	// Successfully connected
	loop_push_event(data.event_loop, Event_State_Changed{.Ready})
	receive_string(&client) // consume the MPD version message

	trace(.INFO, "Successfully connected")

	// Loop forever
	for {
		action: for {
			switch a in loop_pop_action(data.event_loop) {
			case nil:
				break action
			case Action:
				err := handle_action(&client, data.event_loop, a)
				error_trace(err)
			}
		}

		time.sleep(30 * time.Millisecond)
	}
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
		request_status(client) or_return
		status := receive_status(client) or_return
		loop_push_event(event_loop, Event_Status{status})
	}

	return nil
}

error_trace :: proc(error: Error) {
	if error == nil do return

	switch e in error {
	case Error_Kind:
		switch e {
		case .None:
		case .Parse_IP:
			trace(.ERROR, "Failed to parse IP")
		case .Cmd_Invalid_Size:
			trace(.ERROR, "COMMAND: Sent invalid number of bytes")
		case .Response_Not_OK:
			trace(.ERROR, "RESPONSE: Received response is not OK")
		case .Response_Expected_String:
			trace(.ERROR, "RESPONSE: Expected a valid UTF-8 string")
		case .Response_Invalid_Pair:
			trace(.ERROR, "RESPONSE: Invalid pair")
		case .Respose_Pair_Expected_Number:
			trace(.ERROR, "RESPONSE: Pair value expected to be a number")
		}
	case net.Network_Error:
		trace(.ERROR, "Network error: %s", e)
	}
}

trace :: proc(level: raylib.TraceLogLevel, msg: string, args: ..any) {
	sb := strings.builder_make()
	fmt.sbprint(&sb, "CLIENT: ")
	fmt.sbprintf(&sb, msg, ..args)
	raylib.TraceLog(level, strings.to_cstring(&sb))
}
