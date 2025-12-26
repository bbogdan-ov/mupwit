package client

import "core:fmt"
import "core:net"
import "core:strings"
import "core:thread"
import "core:time"
import "vendor:raylib"

import "../loop"

DEFAULT_IP: string : "127.0.0.1"
// MPD uses this port by default
DEFAULT_PORT: int : 6600

Error_Kind :: enum {
	None = 0,
	Invalid_Size,
	Not_OK,
	Expected_String,
	Invalid_Pair,
	Pair_Not_Number,
}

Error :: union {
	Error_Kind,
	net.Network_Error,
	net.TCP_Recv_Error,
}

@(private)
Connect_Data :: struct {
	event_loop: ^loop.Event_Loop,
	addr:       net.IP4_Address,
	port:       int,
}

State :: enum {
	Connecting,
	Ready,
	Error,
}

// Open a connection with the MPD server
connect :: proc(loop: ^loop.Event_Loop, ip := DEFAULT_IP, port := DEFAULT_PORT) {
	addr, ok := net.parse_ip4_address(ip)
	if !ok {
		panic("TODO: catch error")
	}

	data := new(Connect_Data)
	data.event_loop = loop
	data.addr = addr
	data.port = port

	t := thread.create(do_connect)
	t.data = data
	thread.start(t)
}

@(private)
do_connect :: proc(t: ^thread.Thread) {
	data := (^Connect_Data)(t.data)

	time.sleep(1 * time.Second)

	sock, err := net.dial_tcp(data.addr, data.port)
	if err != nil {
		panic("TODO: catch error")
	}

	// Successfully connected
	loop.push_event(data.event_loop, loop.Event_Client_Ready{})
	receive_string(sock) // consume the MPD version message

	trace(.INFO, "Successfully connected")

	// Loop forever
	for {
		action: for {
			switch a in loop.pop_action(data.event_loop) {
			case nil:
				break action
			case loop.Action:
				handle_action(sock, data.event_loop, a)
			}
		}

		time.sleep(30 * time.Millisecond)
	}
}

@(private)
handle_action :: proc(sock: net.TCP_Socket, event_loop: ^loop.Event_Loop, action: loop.Action) {
	switch a in action {
	case loop.Action_Play:
		execute(sock, "pause 0")
		receive_ok(sock)
	case loop.Action_Pause:
		execute(sock, "pause 1")
		receive_ok(sock)
	case loop.Action_Req_Status:
		request_status(sock)

		status, err := receive_status(sock)
		if err != nil {
			trace(.ERROR, "STATUS: Unable to receive the playback status: %s", err)
			return
		}

		loop.push_event(event_loop, loop.Event_Song_Pos(status.cur_song_pos))
	}
}

trace :: proc(level: raylib.TraceLogLevel, msg: string, args: ..any) {
	// Is this a good way to format Odin's strings?
	sb := strings.builder_make()
	fmt.sbprint(&sb, "CLIENT: ")
	fmt.sbprintf(&sb, msg, ..args)
	raylib.TraceLog(level, strings.to_cstring(&sb))
}
