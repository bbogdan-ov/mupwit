package client

import "core:fmt"
import "core:net"
import "core:strings"

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
cmd_immediate :: proc(sock: net.TCP_Socket, args: ..any) -> Error {
	c := cmd_make()
	defer cmd_destroy(&c)
	cmd_append(&c, ..args)
	cmd_exec(&c, sock) or_return
	return nil
}

cmd_exec :: proc(cmd: ^Cmd, sock: net.TCP_Socket) -> Error {
	s := fmt.sbprint(&cmd.builder, '\n')
	defer strings.builder_reset(&cmd.builder)
	cmd_send(s, sock) or_return

	res := response_read(sock) or_return
	defer response_destroy(&res)

	response_ensure_ok(res) or_return

	return nil
}

cmd_send :: proc(s: string, sock: net.TCP_Socket) -> Error {
	size, err := net.send(sock, transmute([]u8)s)
	if err != nil {
		trace(.ERROR, "COMMAND: Unable to send command `%s`: %s", s, err)
		return err
	}
	if size != len(s) {
		trace(.ERROR, "COMMAND: Sent invalid number of bytes %d, expected %d", size, len(s))
		return .Invalid_Size
	}
	return nil
}
