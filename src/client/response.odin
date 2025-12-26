package client

import "core:bytes"
import "core:net"
import "core:unicode/utf8"

Response :: struct {
	bytes: [dynamic]byte,
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

response_ensure_ok :: proc(res: Response) -> Error {
	str := response_string(res)
	switch s in str {
	case nil:
		trace(.ERROR, "RESPONSE: Received response is not OK: (invalid utf8 string)")
		return .Not_OK
	case string:
		if s != "OK" {
			trace(.ERROR, "RESPONSE: Received response is not OK: %s", s)
			return .Not_OK
		}
	}
	return nil
}

response_read :: proc(sock: net.TCP_Socket) -> (res: Response, err: Error) {
	buffer := bytes.Buffer{}
	bytes.buffer_init_allocator(&buffer, len = 0, cap = 128)

	length := 0

	for {
		tmp := [128]byte{}

		size, err := net.recv(sock, tmp[:])
		if err != nil {
			trace(.ERROR, "RESPONSE: Unable to receive a response: %s", err)
			return Response{}, err
		}

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
