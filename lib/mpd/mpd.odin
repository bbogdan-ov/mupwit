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
	net.Set_Blocking_Error,
}

Recv_State :: struct {
	sb:              strings.Builder,
	stop_on_newline: bool,
	is_error:        bool,
}

Client :: struct {
	socket: net.TCP_Socket,
	state:  Recv_State,
}

recv_state_make :: proc(allocator := context.allocator) -> Recv_State {
	s: Recv_State
	s.sb = strings.builder_make(allocator)
	return s
}

recv_state_destroy :: proc(state: ^Recv_State) {
	strings.builder_destroy(&state.sb)
}

recv_state_reset :: proc(state: ^Recv_State) {
	strings.builder_reset(&state.sb)

	state^ = {
		sb = state.sb,
	}
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
	log.debug("MPD: Connecting...")

	dial_err: net.Network_Error
	client.socket, dial_err = net.dial_tcp(endpoint)
	if dial_err != nil {
		log.errorf("MPD: Failed to connect: %v", dial_err)
		return client, dial_err
	}

	net.set_blocking(client.socket, false) or_return

	client.state = recv_state_make(allocator)

	{
		// TODO: handle not receiving "hello" message.
		version := recv_blocking(&client, context.allocator, loc) or_return
		defer delete(version, context.allocator)

		log.debugf("MPD: Connected: %q", version)
	}

	return client, nil
}

disconnect :: proc(client: ^Client) {
	net.close(client.socket)
	recv_state_destroy(&client.state)
}

@(require_results)
recv_blocking :: proc(
	client: ^Client,
	allocator := context.allocator,
	loc := #caller_location,
) -> (
	str: string,
	err: Error,
) {
	for {
		received: bool
		str, received = recv(client, allocator, loc) or_return
		if received do break
	}
	return
}

@(require_results)
recv :: proc(
	client: ^Client,
	allocator := context.allocator,
	loc := #caller_location,
) -> (
	str: string,
	received: bool,
	err: Error,
) {
	ss :: strings
	starts_with :: ss.starts_with
	ends_with :: ss.ends_with

	sb := &client.state.sb

	@(static) buffer: [512]u8
	loop: for {
		size, err := net.recv(client.socket, buffer[:])

		if size <= 0 && err != .Would_Block {
			err = .Connection_Closed
		}

		if err == .Would_Block {
			return "", false, nil
		} else if err != nil {
			log.errorf("MPD: Failed to receive: %v", err, location = loc)
			recv_state_reset(&client.state)
			return "", false, err
		}

		was_empty := len(sb.buf) == 0
		ss.write_string(sb, string(buffer[:size]))
		as_str := ss.trim_space(ss.to_string(sb^))

		if was_empty {
			if starts_with(as_str, "OK ") {
				client.state.stop_on_newline = true
			} else if starts_with(as_str, "ACK ") {
				client.state.is_error = true
				client.state.stop_on_newline = true
			}
		}

		if size < len(buffer) do break
		if ends_with(as_str, "\nOK") do break
		if client.state.stop_on_newline && ends_with(as_str, "\n") do break
	}

	// TODO!!: store message somewhere if it is an error. ("ACK ..." message)
	str = ss.trim_space(ss.to_string(sb^))
	str = ss.clone(str, allocator)

	recv_state_reset(&client.state)

	received = true
	return
}

// Send a command.
@(require_results)
send :: proc(
	client: ^Client,
	$format: string,
	args: ..any,
	loc := #caller_location,
) -> (
	err: Error,
) {
	str := fmt.tprintf(format + "\n", ..args)
	_, err = net.send_tcp(client.socket, transmute([]u8)str)
	if err != nil {
		log.errorf("MPD: Failed to send: %v", err, location = loc)
	}
	return
}
