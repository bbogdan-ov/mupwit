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

Status_Connecting :: struct {
	addr: net.IP4_Address,
	port: int,
}

Status_Ready :: struct {
	sock: net.TCP_Socket,
}

Status_Error :: struct {}

Status :: union {
	Status_Connecting,
	Status_Ready,
	Status_Error,
}

Client :: struct {
	loop:   ^loop.Event_Loop,
	status: Status,
}

// Open a connection with the MPD server
connect :: proc(loop: ^loop.Event_Loop, ip := DEFAULT_IP, port := DEFAULT_PORT) -> ^Client {
	addr, ok := net.parse_ip4_address(ip)
	if !ok {
		panic("TODO: catch error")
	}

	client := new(Client)
	client.loop = loop
	client.status = Status_Connecting{addr, port}

	t := thread.create(do_connect)
	t.data = client
	thread.start(t)

	return client
}

@(private)
do_connect :: proc(t: ^thread.Thread) {
	client := (^Client)(t.data)

	#partial switch s in client.status {
	case Status_Connecting:
		dial(client, s)
	case:
		panic(fmt.tprint("client must be in `Connecting` state, but got", s))
	}

}

@(private)
dial :: proc(client: ^Client, status: Status_Connecting) {
	time.sleep(1 * time.Second)

	sock, err := net.dial_tcp(status.addr, status.port)
	if err != nil {
		panic("TODO: catch error")
	}

	// Successfully connected

	// Consume the MPD version message
	response_read(sock)

	client.status = Status_Ready {
		sock = sock,
	}
	loop.push_event(client.loop, loop.Event_Client_Ready{})

	trace(.INFO, "Successfully connected")

	for {
		action: for {
			switch a in loop.pop_action(client.loop) {
			case nil:
				break action
			case loop.Action:
				handle_action(client, sock, a)
			}
		}
		time.sleep(30 * time.Millisecond)
	}

}

@(private)
handle_action :: proc(client: ^Client, sock: net.TCP_Socket, action: loop.Action) {
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
