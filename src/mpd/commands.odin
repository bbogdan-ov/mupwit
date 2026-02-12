package mpd

import "core:fmt"
import "core:log"
import "core:net"

// Execute a MPD command.
executef :: proc(client: ^Client, format: string, args: ..any) -> Error {
	return _cmd_send(client, fmt.tprintfln(format, ..args))
}

@(private)
_cmd_send :: proc(client: ^Client, cmd: string) -> Error {
	size, err := net.send(client.sock, transmute([]u8)cmd)
	if err != nil {
		log.errorf("CLIENT: Unable to send command `%s`: %s", cmd, err)
		return err
	}
	if size != len(cmd) do return .Cmd_Invalid_Size
	return nil
}
