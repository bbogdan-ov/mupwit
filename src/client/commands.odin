package client

import "core:net"

Cmd :: distinct string

// Execute a static MPD command
execute :: #force_inline proc(sock: net.TCP_Socket, $s: string) -> Error {
	return cmd_send(sock, Cmd(s + "\n"))
}

@(private)
cmd_send :: proc(sock: net.TCP_Socket, cmd: Cmd) -> Error {
	size, err := net.send(sock, transmute([]u8)cmd)
	if err != nil {
		trace(.ERROR, "COMMAND: Unable to send command `%s`: %s", cmd, err)
		return err
	}
	if size != len(cmd) {
		trace(.ERROR, "COMMAND: Sent invalid number of bytes %d, expected %d", size, len(cmd))
		return .Invalid_Size
	}
	return nil
}
