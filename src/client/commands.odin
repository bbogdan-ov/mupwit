package client

import "core:fmt"
import "core:net"
import "core:strings"

// Execute a MPD command
execute :: proc(client: ^Client, args: ..any) -> Error {
	sb := strings.builder_make()
	fmt.sbprintln(&sb, ..args)
	return cmd_send(client, strings.to_string(sb))
}

@(private)
cmd_send :: proc(client: ^Client, cmd: string) -> Error {
	size := net.send(client.sock, transmute([]u8)cmd) or_return
	if size != len(cmd) do return .Cmd_Invalid_Size
	return nil
}
