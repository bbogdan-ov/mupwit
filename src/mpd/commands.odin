package mpd

import "core:fmt"
import "core:net"
import "core:strings"

// Format and execute a MPD command
executef :: proc(client: ^Client, format: string, args: ..any) -> Error {
	sb := strings.builder_make()
	defer strings.builder_destroy(&sb)
	fmt.sbprintfln(&sb, format, ..args)
	return cmd_send(client, strings.to_string(sb))
}

@(private)
cmd_send :: proc(client: ^Client, cmd: string) -> Error {
	size, err := net.send(client.sock, transmute([]u8)cmd)
	if err != nil {
		set_error(client, "Unable to send command")
		return err
	}
	if size != len(cmd) do return .Cmd_Invalid_Size
	return nil
}
