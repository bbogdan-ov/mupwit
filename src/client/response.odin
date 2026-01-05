package client

import "core:bytes"
import "core:net"
import "core:strconv"
import "core:strings"
import "core:unicode/utf8"

import "../util"

Pair :: struct {
	// Slice of `Response.buffer`
	name:  string,
	// Slice of `Response.buffer`
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
	buffer: bytes.Buffer,
}

receive :: proc(client: ^Client) -> (res: Response, err: Error) {
	buffer := bytes.Buffer{}
	bytes.buffer_init_allocator(&buffer, len = 0, cap = 32)

	length := 0

	for {
		tmp: [128]byte = ---

		size, err := net.recv_tcp(client.sock, tmp[:])
		if err != nil do return Response{}, net.Network_Error(err)
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

	s := string(buffer.buf[:])
	if strings.starts_with(s, "ACK") {
		// Error response
		client.error_msg = s
		return Response{}, .Mpd_Error
	}

	return Response{buffer}, nil
}

response_destroy :: proc(res: ^Response) {
	bytes.buffer_destroy(&res.buffer)
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

response_next_binary :: proc(res: ^Response) -> (binary: [dynamic]byte, err: Error) {
	pair := response_expect_pair(res, "binary") or_return
	size := pair_parse_int(pair) or_return

	b := make([dynamic]byte, len = size, cap = size)
	_, _ = bytes.buffer_read(&res.buffer, b[:])
	res.buffer.off += 1 // skip the newline char at the end of binary data

	if len(b) == size {
		return b, nil
	} else {
		return {}, .Response_Unexpected_Binary_Size
	}
}

response_next_string :: proc(res: ^Response) -> (str: string, err: Error) {
	s, _ := bytes.buffer_read_string(&res.buffer, '\n')
	if utf8.valid_string(s) {
		return s, nil
	} else {
		return "", .Response_Expected_String
	}
}

response_next_pair :: proc(res: ^Response) -> (pair: Pair, err: Error) {
	s := response_next_string(res) or_return

	if s == "OK" do return Pair{}, .End_Of_Response

	left, right, ok := util.split_once(s, ':')
	if !ok do return Pair{}, .Response_Invalid_Pair

	pair.name = strings.trim_space(left)
	pair.value = strings.trim_space(right)

	return
}

response_expect_pair :: #force_inline proc(
	res: ^Response,
	name: string,
) -> (
	pair: Pair,
	err: Error,
) {
	p := response_next_pair(res) or_return
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
	last_offset := res.buffer.off
	p := response_next_pair(res) or_return
	if string(p.name) == name {
		return p, nil
	} else {
		res.buffer.off = last_offset
		return nil, nil
	}
}
