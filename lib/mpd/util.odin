package mpd

import "core:os"
import "core:strconv"
import "core:strings"

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
