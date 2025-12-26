package client

import "core:bytes"
import "core:net"
import "core:strconv"
import "core:strings"
import "core:unicode/utf8"

Pair :: struct {
	name:  string,
	value: string,
}

Pairs :: struct {
	// All pairs will take a view from this string for their names and values
	str:  string,
	list: [dynamic]Pair,
}

receive_binary :: proc(sock: net.TCP_Socket) -> (binary: [dynamic]byte, err: Error) {
	buffer := bytes.Buffer{}
	bytes.buffer_init_allocator(&buffer, len = 0, cap = 128)

	length := 0

	for {
		tmp: [128]byte = ---

		size, err := net.recv_tcp(sock, tmp[:])
		if err != nil {
			trace(.ERROR, "RESPONSE: Unable to receive a response: %s", err)
			return nil, err
		}
		if size <= 0 do break

		bytes.buffer_write_at(&buffer, tmp[:], length)
		length += size

		if size < len(tmp) do break
	}

	if length <= 0 {
		// Empty response
		return nil, nil
	}

	bytes.buffer_truncate(&buffer, length)

	// Trim the newline character at the end
	if buffer.buf[length - 1] == '\n' {
		bytes.buffer_truncate(&buffer, length - 1)
	}

	return buffer.buf, nil
}

receive_string :: proc(sock: net.TCP_Socket) -> (str: string, err: Error) {
	binary := receive_binary(sock) or_return
	s := string(binary[:])
	if utf8.valid_string(s) {
		return s, nil
	} else {
		return "", .Expected_String
	}
}

receive_ok :: proc(sock: net.TCP_Socket) -> Error {
	s := receive_string(sock) or_return
	defer delete(s)
	if s != "OK" {
		trace(.ERROR, "RESPONSE: Received response is not OK: %s", s)
		return .Not_OK
	}
	return nil
}

receive_pairs :: proc(sock: net.TCP_Socket) -> (pairs: Pairs, err: Error) {
	s := receive_string(sock) or_return

	pairs.str = s
	pairs.list = make([dynamic]Pair, len = 0, cap = 10)

	for line in strings.split_lines(s) {
		if line == "OK" do break

		parts := strings.split_n(line, ":", 2)
		if len(parts) != 2 do return Pairs{}, .Invalid_Pair

		pair := Pair {
			name  = strings.trim_space(parts[0]),
			value = strings.trim_space(parts[1]),
		}
		append(&pairs.list, pair)
	}

	return pairs, nil
}

pairs_destroy :: proc(pairs: Pairs) {
	delete(pairs.list)
	delete(pairs.str)
}

pair_parse_int :: proc(pair: Pair) -> (number: int, err: Error) {
	num, ok := strconv.parse_int(pair.value)
	if !ok do return 0, .Pair_Not_Number
	return num, nil
}
pair_parse_f32 :: proc(pair: Pair) -> (number: f32, err: Error) {
	num, ok := strconv.parse_f32(pair.value)
	if !ok do return 0, .Pair_Not_Number
	return num, nil
}
