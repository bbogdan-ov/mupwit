package client

import "core:fmt"
import "core:net"
import "core:strings"

Cmd_Error_Kind :: enum {
	None = 0,
	Invalid_Size,
}

Cmd_Error :: union #shared_nil {
	Cmd_Error_Kind,
	net.Network_Error,
}

Cmd :: struct {
	builder: strings.Builder,
}

cmd_make :: proc() -> Cmd {
	return Cmd{builder = strings.builder_make()}
}

cmd_destroy :: proc(cmd: ^Cmd) {
	strings.builder_destroy(&cmd.builder)
}

cmd_append :: proc(cmd: ^Cmd, args: ..any) {
	fmt.sbprint(&cmd.builder, ..args)
}

// Immediately allocate and execute a MPD command
cmd_immediate :: proc(sock: net.TCP_Socket, args: ..any) {
	c := cmd_make()
	defer cmd_destroy(&c)
	cmd_append(&c, ..args)
	cmd_exec(&c, sock)
}

cmd_exec :: #force_inline proc(cmd: ^Cmd, sock: net.TCP_Socket) {
	err := cmd_exec_err(cmd, sock)
	if err != nil {
		s := strings.to_string(cmd.builder)
		trace(.ERROR, "Unable to execute command `%s`: %s", s, err)
	}
}

cmd_exec_err :: proc(cmd: ^Cmd, sock: net.TCP_Socket) -> Cmd_Error {
	s := fmt.sbprint(&cmd.builder, '\n')
	defer strings.builder_reset(&cmd.builder)
	return cmd_send(s, sock)
}

cmd_send :: proc(s: string, sock: net.TCP_Socket) -> Cmd_Error {
	size, err := net.send(sock, transmute([]u8)s)
	if err != nil {return err}
	if size != len(s) {return .Invalid_Size}
	return nil
}
