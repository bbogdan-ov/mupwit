#+vet explicit-allocators

// Music Player Daemon client library.

package mpd

import "base:intrinsics"
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
connect :: proc(allocator := context.allocator) -> (client: Client, err: Error) {
	port := get_port()
	host := get_host(context.allocator)
	defer delete(host, context.allocator)

	endpoint := net.parse_hostname_or_endpoint(fmt.tprintf("%v:%v", host, port)) or_return

	return connect_to_endpoint(endpoint, allocator)
}

@(require_results)
connect_to_endpoint :: proc(
	endpoint: net.Host_Or_Endpoint,
	allocator := context.allocator,
	loc := #caller_location,
) -> (
	client: Client,
	err: Error,
) {
	log.info("MPD: Connecting...")

	dial_err: net.Network_Error
	client.socket, dial_err = net.dial_tcp(endpoint)
	if dial_err != nil {
		log.errorf("MPD: Failed to connect: %v", dial_err)
		return client, dial_err
	}

	{
		// TODO: handle not receiving "hello" message.
		version := recv(&client, context.allocator, loc) or_return
		defer delete(version, context.allocator)

		log.infof("MPD: Connected: %q", version)
	}

	return client, nil
}

disconnect :: proc(client: ^Client) {
	log.info("MPD: Disconnecting...")
	net.close(client.socket)
}

@(require_results)
recv_and_parse :: #force_inline proc(
	client: ^Client,
	allocator := context.allocator,
	loc := #caller_location,
) -> (
	parser: Parser,
	err: Error,
) {
	str := recv(client, allocator, loc) or_return
	parser = parser_make(str)
	return
}

@(require_results)
recv_and_forget :: proc(client: ^Client, loc := #caller_location) -> (err: Error) {
	str: string
	// TODO!: should not allocate the string, but i have to for now because i
	// need to collect the whole response string in order to determine whether
	// it is ended.
	str, err = recv(client, context.allocator, loc)
	delete(str, context.allocator)
	return
}

@(require_results)
recv :: proc(
	client: ^Client,
	allocator := context.allocator,
	loc := #caller_location,
) -> (
	str: string,
	err: Error,
) {
	ss :: strings

	sb := ss.builder_make(allocator)
	stop_on_newline := false
	is_error := false

	@(static) buffer: [256]u8
	loop: for {
		size, err := net.recv(client.socket, buffer[:])
		if size <= 0 {
			err = .Connection_Closed
		}

		if err != nil {
			log.errorf("MPD: Failed to receive: %v", err, location = loc)
			return "", err
		}

		was_empty := len(sb.buf) == 0
		ss.write_string(&sb, string(buffer[:size]))
		as_str := ss.to_string(sb)

		if was_empty {
			if ss.starts_with(as_str, "OK ") {
				stop_on_newline = true
			} else if ss.starts_with(as_str, "ACK ") {
				is_error = true
				stop_on_newline = true
			}
		}

		if as_str == "OK\n" do break
		if ss.ends_with(as_str, "\nOK\n") do break
		if stop_on_newline && ss.ends_with(as_str, "\n") do break

		// FIXME!: sometimes it may receive buffer of a smaller size even tho
		// it is not the end of the response. It fails very often on large
		// responses, didn't see any issues with small ones.
		//
		// if size < len(buffer) do break
	}

	// TODO!!: store message somewhere if it is an error. ("ACK ..." message)
	str = ss.trim_space(ss.to_string(sb))
	return
}

@(require_results)
_send_string :: proc(client: ^Client, str: string, loc := #caller_location) -> (err: Error) {
	if len(str) == 0 do return nil

	_, err = net.send_tcp(client.socket, transmute([]u8)str)
	if err != nil {
		log.errorf("MPD: Failed to send: %v", err, location = loc)
	}
	return err
}

@(require_results)
send_const :: proc(client: ^Client, $str: string, loc := #caller_location) -> (err: Error) {
	return _send_string(client, str + "\n", loc)
}

@(require_results)
send_and_forget :: proc(
	client: ^Client,
	command: string,
	args: ..any,
	allocator := context.allocator,
	loc := #caller_location,
) -> (
	err: Error,
) {
	cmd := cmd_begin(command, allocator)
	if len(args) > 0 {
		strings.write_byte(&cmd, ' ')
		fmt.sbprint(&cmd, ..args)
	}
	cmd_send(client, &cmd, loc) or_return
	return recv_and_forget(client, loc)
}
