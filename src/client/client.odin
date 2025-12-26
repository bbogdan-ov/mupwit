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
}

Error :: union {
	Error_Kind,
	net.Network_Error,
	net.TCP_Recv_Error,
}

@(private)
Connect_Data :: struct {
	loop: ^loop.Event_Loop,
	addr: net.IP4_Address,
	port: int,
}

Status :: enum {
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
	data.loop = loop
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
	loop.push_event(data.loop, loop.Event_Client_Ready{})
	response_read(sock) // consume the MPD version message

	trace(.INFO, "Successfully connected")

	// Loop forever
	for {
		action: for {
			switch a in loop.pop_action(data.loop) {
			case nil:
				break action
			case loop.Action:
				handle_action(sock, a)
			}
		}

		time.sleep(30 * time.Millisecond)
	}
}

@(private)
handle_action :: proc(sock: net.TCP_Socket, action: loop.Action) {
	switch a in action {
	case loop.Action_Play:
		cmd_immediate(sock, "pause 0")
	case loop.Action_Pause:
		cmd_immediate(sock, "pause 1")
	}
}

trace :: proc(level: raylib.TraceLogLevel, msg: string, args: ..any) {
	// Is this a good way to format Odin's strings?
	sb := strings.builder_make()
	fmt.sbprint(&sb, "CLIENT: ")
	fmt.sbprintf(&sb, msg, ..args)
	raylib.TraceLog(level, strings.to_cstring(&sb))
}
