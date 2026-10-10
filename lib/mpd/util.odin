package mpd

import "core:net"
import "core:os"
import "core:strconv"
import "core:strings"

DEFAULT_PORT :: 6600

// Get host address from `MPD_HOST` env or the default one.
get_host :: proc(allocator := context.allocator) -> string {
	host := os.get_env("MPD_HOST", allocator)
	if host == "" {
		delete(host, allocator)
		return strings.clone("localhost", allocator)
	}
	return host
}

// Get connection port from `MPD_PORT` env or the default one.
get_port :: proc() -> int {
	port := os.get_env("MPD_PORT", context.temp_allocator)
	return strconv.parse_int(port) or_else DEFAULT_PORT
}

endpoint_to_string :: proc(
	endpoint: net.Host_Or_Endpoint,
	allocator := context.allocator,
	loc := #caller_location,
) -> string {
	sb := strings.builder_make(allocator, loc)
	switch ep in endpoint {
	case net.Host:
		strings.write_string(&sb, ep.hostname)
		if ep.port > 0 {
			strings.write_byte(&sb, ':')
			strings.write_int(&sb, ep.port)
		}
	case net.Endpoint:
		net.endpoint_to_string_builder(ep, &sb)
	case:
		unreachable()
	}
	return strings.to_string(sb)
}

// Quotes ONLY special characters (`"`, `\`) inside a string and encloses it
// into double quotes.
write_quoted_string :: proc(sb: ^strings.Builder, str: string) {
	strings.write_byte(sb, '"')
	for i in 0 ..< len(str) {
		switch str[i] {
		case '"', '\\':
			strings.write_byte(sb, '\\')
		}
		strings.write_byte(sb, str[i])
	}
	strings.write_byte(sb, '"')
}

quote_string :: proc(str: string, allocator := context.allocator) -> string {
	sb := strings.builder_make(allocator)
	write_quoted_string(&sb, str)
	return strings.to_string(sb)
}
