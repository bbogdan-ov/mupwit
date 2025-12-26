package client

import "core:net"

Cmd :: distinct string

// Execute a static MPD command
execute :: #force_inline proc(client: ^Client, $s: string) -> Error {
	return cmd_send(client, Cmd(s + "\n"))
}

@(private)
cmd_send :: proc(client: ^Client, cmd: Cmd) -> Error {
	size := net.send(client.sock, transmute([]u8)cmd) or_return
	if size != len(cmd) do return .Cmd_Invalid_Size
	return nil
}
