package mpd

import "core:fmt"
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

// ------------------------------
// Strings.
// ------------------------------

format_seconds :: proc(secs: Seconds, allocator := context.allocator) -> string {
	sb := strings.builder_make(allocator)
	d := int(secs)
	if d < 60 {
		fmt.sbprintf(&sb, "00:%02d", d)
	} else if d < 60 * 60 {
		fmt.sbprintf(&sb, "%02d:%02d", d / 60, d % 60)
	} else {
		hours := d / 60 / 60
		mins := d / 60 % 60
		secs := d % 60
		fmt.sbprintf(&sb, "%02d:%02d:%02d", hours, mins, secs)
	}
	return strings.to_string(sb)
}
