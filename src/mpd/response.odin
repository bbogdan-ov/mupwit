package mpd

import "core:bytes"
import "core:net"
import "core:strconv"
import "core:strings"
import "core:unicode/utf8"

import "../util"

Pair :: struct {
	// Slice from `Response.buffer`
	name:  string,
	// Slice from `Response.buffer`
	value: string,
}

pair_parse_int :: proc(pair: Pair) -> (number: int, err: Error) {
	num, ok := strconv.parse_int(string(pair.value))
	if !ok do return 0, .Pair_Expected_Number
	return num, nil
}
pair_parse_f32 :: proc(pair: Pair) -> (number: f32, err: Error) {
	num, ok := strconv.parse_f32(string(pair.value))
	if !ok do return 0, .Pair_Expected_Number
	return num, nil
}

Response :: struct {
	buf:    [dynamic]byte,
	offset: int,
}

receive :: proc(client: ^Client, loc := #caller_location) -> (res: Response, err: Error) {
	buffer := bytes.Buffer{}
	bytes.buffer_init_allocator(&buffer, len = 0, cap = 32)

	length := 0

	for {
		tmp: [256]byte = ---

		size, err := net.recv_tcp(client.sock, tmp[:])
		if err != nil do return Response{}, net.Network_Error(err)
		if size <= 0 do break

		bytes.buffer_write_at(&buffer, tmp[:size], length)
		length += size

		s := string(tmp[:size])
		ok_end := strings.ends_with(s, "OK\n")
		error_end := strings.starts_with(s, "ACK") && strings.ends_with(s, "\n")
		if size < len(tmp) || ok_end || error_end do break
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

	s := string(buffer.buf[:])
	if strings.starts_with(s, "ACK") {
		// Received an error response.
		// See https://mpd.readthedocs.io/en/latest/protocol.html#failure-responses

		// FIXME!: setting this error message will leak some memory.
		// `set_error` expects a static string, but we supply an allocated one.

		// Just set the received error code as an error message.
		// I don't really care to parse it into more "user-friendly" format.
		set_error(client, s, loc)

		return Response{}, .Mpd_Error
	}

	return Response{buf = buffer.buf, offset = 0}, nil
}

response_destroy :: proc(res: ^Response) {
	delete(res.buf)
	res.buf = nil
}

receive_ok :: proc(client: ^Client) -> Error {
	res := receive(client) or_return
	defer response_destroy(&res)
	return response_expect_ok(&res)
}

response_expect_ok :: proc(res: ^Response) -> Error {
	s := response_next_string(res) or_return
	if s == "OK" {
		return nil
	} else {
		return .Response_Not_OK
	}
}

response_next_binary :: proc(res: ^Response) -> (binary: []byte, err: Error) {
	pair := response_expect_pair(res, "binary") or_return
	size := pair_parse_int(pair) or_return

	end := res.offset + size
	binary = res.buf[res.offset:end]
	res.offset += size + 1 // + 1 to skip the newline char at the end of binary data

	if len(binary) != size {
		return {}, .Response_Unexpected_Binary_Size
	}

	return
}

response_next_string :: proc(res: ^Response) -> (str: string, err: Error) {
	idx := bytes.index_byte(res.buf[res.offset:], '\n')

	end: int
	if idx >= 0 {
		end = res.offset + idx + 1 // + 1 including newline
	} else {
		end = len(res.buf)
	}

	s := string(res.buf[res.offset:end])
	res.offset = end

	if utf8.valid_string(s) {
		return s, nil
	} else {
		return "", .Response_Expected_String
	}
}

response_next_pair :: proc(res: ^Response) -> (pair: Maybe(Pair), err: Error) {
	s := response_next_string(res) or_return

	if strings.trim_space(s) == "OK" do return nil, nil

	left, right, ok := util.split_once(s, ':')
	if !ok do return Pair{}, .Response_Invalid_Pair

	p := Pair {
		name  = strings.trim_space(left),
		value = strings.trim_space(right),
	}

	return p, nil
}

response_expect_pair :: #force_inline proc(
	res: ^Response,
	name: string,
) -> (
	pair: Pair,
	err: Error,
) {
	maybe := response_next_pair(res) or_return
	p, ok := maybe.?
	if !ok do return Pair{}, .End_Of_Response

	if string(p.name) != name do return Pair{}, .Unexpected_Pair
	return p, nil
}

response_optional_pair :: #force_inline proc(
	res: ^Response,
	name: string,
) -> (
	pair: Maybe(Pair),
	err: Error,
) {
	last_offset := res.offset
	maybe := response_next_pair(res) or_return
	p, ok := maybe.?
	if !ok do return nil, nil

	if string(p.name) == name {
		return p, nil
	} else {
		res.offset = last_offset
		return nil, nil
	}
}
