package mpd

import "core:fmt"
import "core:log"
import "core:net"

// Execute a MPD command.
@(require_results)
executef :: proc(client: ^Client, format: string, args: ..any) -> (err: Error) {
	return _cmd_send(client, fmt.tprintfln(format, ..args))
}

@(private, require_results)
_cmd_send :: proc(client: ^Client, cmd: string) -> (err: Error) {
	size: int
	size, err = net.send(client.sock, transmute([]u8)cmd)
	if err != nil {
		log.errorf("CLIENT: Unable to send command `%s`: %s", cmd, err)
		return err
	}
	if size != len(cmd) {
		log.errorf(
			"CLIENT: Sent invalid number of command string bytes, expected %d but got %d",
			len(cmd),
			size,
		)
		return .Cmd_Invalid_Size
	}
	return nil
}
