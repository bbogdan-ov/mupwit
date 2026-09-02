#+vet explicit-allocators

// Music Player Daemon client library.

package mpd

import "core:fmt"
import "core:log"
import "core:net"
import "core:strings"

DEFAULT_PORT :: 6600

Error :: union #shared_nil {
	net.Network_Error,
	net.TCP_Recv_Error,
	net.TCP_Send_Error,
	net.Parse_Endpoint_Error,
}

Client :: struct {
	socket: net.TCP_Socket,
}

@(require_results)
connect :: proc() -> (client: Client, err: Error) {
	port := get_port()
	host := get_host(context.allocator)
	defer delete(host, context.allocator)

	endpoint := net.parse_hostname_or_endpoint(fmt.tprintf("%v:%v", host, port)) or_return

	return connect_to_endpoint(endpoint)
}

@(require_results)
connect_to_endpoint :: proc(
	endpoint: net.Host_Or_Endpoint,
	loc := #caller_location,
) -> (
	client: Client,
	err: Error,
) {
	log.debug("MPD: Connecting...")

	dial_err: net.Network_Error
	client.socket, dial_err = net.dial_tcp(endpoint)
	if dial_err != nil {
		log.errorf("MPD: Failed to connect: %v", dial_err)
		return client, dial_err
	}

	{
		// TODO: handle not receiving "hello" message.
		version := recv_string(&client, context.allocator, loc) or_return
		defer delete(version, context.allocator)

		log.debugf("MPD: Connected: %q", version)
	}

	return client, nil
}

disconnect :: proc(client: ^Client) {
	net.close(client.socket)
}

@(require_results)
recv_and_parse :: proc(
	client: ^Client,
	allocator := context.allocator,
	loc := #caller_location,
) -> (
	parser: Parser,
	err: Error,
) {
	s := recv_string(client, allocator, loc) or_return
	return parser_make(s), nil
}

@(require_results)
recv_string :: proc(
	client: ^Client,
	allocator := context.allocator,
	loc := #caller_location,
) -> (
	s: string,
	err: Error,
) {
	starts_with :: strings.starts_with
	ends_with :: strings.ends_with

	// FIXME!!: i'm afraid that it couldn't determine whether it received the
	// entire message with its size is multiple of the buffer size.
	@(static) buffer: [512]u8

	is_error := false
	break_on_newline := false

	sb := strings.builder_make(allocator)

	for {
		size, err := net.recv(client.socket, buffer[:])
		if err != nil {
			log.errorf("MPD: Failed to receive string: %v", err, location = loc)
			strings.builder_destroy(&sb)
			return "", err
		}

		was_empty := len(sb.buf) == 0

		strings.write_string(&sb, string(buffer[:size]))

		as_str := strings.to_string(sb)

		if was_empty {
			if starts_with(as_str, "ACK ") {
				is_error = true
				break_on_newline = true
			} else if starts_with(as_str, "OK ") {
				break_on_newline = true
			}
		}

		if size < len(buffer) do break
		if ends_with(as_str, "\nOK") do break
		if break_on_newline && ends_with(as_str, "\n") do break
	}

	// TODO!!: store message somewhere if it is an error. ("ACK ..." message)
	s = strings.to_string(sb)
	return strings.trim_space(s), nil
}

// Send a command.
@(require_results)
send :: proc(client: ^Client, $format: string, args: ..any) -> (err: Error) {
	str := fmt.tprintf(format + "\n", args)
	_, err = net.send_tcp(client.socket, transmute([]u8)str)
	return
}
