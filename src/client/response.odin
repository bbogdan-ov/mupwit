package client

import "core:bytes"
import "core:net"
import "core:strconv"
import "core:strings"
import "core:unicode/utf8"

Response :: struct {
	bytes: [dynamic]byte,
}

Pair :: struct {
	name:  string,
	value: string,
}

Pairs :: struct {
	// All pairs will take a view from this string for their names and values
	str:  string,
	list: [dynamic]Pair,
}

response_destroy :: proc(res: ^Response) {
	delete(res.bytes)
	res.bytes = nil
}

response_string :: proc(res: Response) -> Maybe(string) {
	s := string(res.bytes[:])
	if utf8.valid_string(s) do return s
	else do return nil
}

response_expect_ok :: proc(sock: net.TCP_Socket) -> Error {
	res := response_receive(sock) or_return
	defer response_destroy(&res)
	return response_ensure_ok(res)
}

response_ensure_ok :: proc(res: Response) -> Error {
	str := response_string(res)
	switch s in str {
	case nil:
		trace(.ERROR, "RESPONSE: Received response is not OK: (binary data)")
		return .Not_OK
	case string:
		if s != "OK" {
			trace(.ERROR, "RESPONSE: Received response is not OK: %s", s)
			return .Not_OK
		}
	}
	return nil
}

response_receive :: proc(sock: net.TCP_Socket) -> (res: Response, err: Error) {
	buffer := bytes.Buffer{}
	bytes.buffer_init_allocator(&buffer, len = 0, cap = 128)

	length := 0

	for {
		tmp: [128]byte = ---

		size, err := net.recv_tcp(sock, tmp[:])
		if err != nil {
			trace(.ERROR, "RESPONSE: Unable to receive a response: %s", err)
			return Response{}, err
		}
		if size <= 0 do break

		bytes.buffer_write_at(&buffer, tmp[:], length)
		length += size

		if size < len(tmp) do break
	}

	if length <= 0 {
		// Empty response
		return Response{}, nil
	}

	bytes.buffer_truncate(&buffer, length)

	// Trim the newline character at the end
	if buffer.buf[length - 1] == '\n' {
		bytes.buffer_truncate(&buffer, length - 1)
	}

	return Response{bytes = buffer.buf}, nil
}

response_receive_string :: proc(sock: net.TCP_Socket) -> (s: string, err: Error) {
	res := response_receive(sock) or_return
	switch s in response_string(res) {
	case string:
		return s, nil
	case:
		return "", .Unexpected_Binary
	}
}

pairs_receive :: proc(sock: net.TCP_Socket) -> (pairs: Pairs, err: Error) {
	s := response_receive_string(sock) or_return

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
	if !ok do return 0, .Pair_Not_Int
	return num, nil
}

pair_parse_f32 :: proc(pair: Pair) -> (number: f32, err: Error) {
	num, ok := strconv.parse_f32(pair.value)
	if !ok do return 0, .Pair_Not_Int
	return num, nil
}
