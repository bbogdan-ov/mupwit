package mpd

import "core:fmt"
import "core:mem"
import "core:strings"
import "core:time"

// Split string exactly into two parts separated by the separator `sep`.
//
// `ok` is false when there is no `sep` in the string.
split_once :: proc(s: string, sep: rune) -> (left, right: string, ok: bool) {
	idx := strings.index_rune(s, sep)
	if idx < 0 do return "", "", false

	// +1 to exclude the separator
	return s[:idx], s[idx + 1:], true
}

maybe_str_delete :: proc(s: Maybe(string)) {
	if str, ok := s.?; ok {
		delete(str)
	}
}

// Escape single quote `'` and double quote `"` characters
espace :: proc(
	s: string,
	allocator := context.temp_allocator,
	loc := #caller_location,
) -> (
	res: string,
	err: mem.Allocator_Error,
) #optional_allocator_error {
	sb := strings.builder_make(len = 0, cap = len(s), allocator = allocator, loc = loc) or_return
	_espace(&sb, s, allocator, loc)
	return strings.to_string(sb), nil
}

// Espace quotes and wrap the string in double quotes `"..."`
quote :: proc(
	s: string,
	allocator := context.temp_allocator,
	loc := #caller_location,
) -> (
	res: string,
	err: mem.Allocator_Error,
) #optional_allocator_error {
	sb := strings.builder_make(
		len = 0,
		cap = len(s) + 2,
		allocator = allocator,
		loc = loc,
	) or_return

	append(&sb.buf, '"')
	_espace(&sb, s, allocator, loc)
	append(&sb.buf, '"')

	return strings.to_string(sb), nil
}

@(private)
_espace :: proc(
	sb: ^strings.Builder,
	s: string,
	allocator := context.temp_allocator,
	loc := #caller_location,
) {
	// Iterating over bytes because we are only operating on ASCII character.
	for byte in transmute([]u8)s {
		switch byte {
		case '\'':
			append(&sb.buf, '\\', byte)
		case '"':
			append(&sb.buf, '\\', byte)
		case '\\':
			append(&sb.buf, '\\', byte)
		case:
			append(&sb.buf, byte)
		}
	}
}

format_duration :: proc(duration: time.Duration, allocator := context.allocator) -> string {
	context.allocator = allocator
	duration := duration

	neg := false
	if duration < 0 {
		duration = -duration
		neg = true
	}

	secs := i32(time.duration_seconds(duration)) % 60
	mins := i32(time.duration_minutes(duration)) % 60
	if duration >= time.Hour {
		hours := i32(time.duration_hours(duration))
		if neg {
			return fmt.aprintf("-%02d:%02d:%02d", hours, mins, secs)
		} else {
			return fmt.aprintf("%02d:%02d:%02d", hours, mins, secs)
		}
	} else {
		if neg {
			return fmt.aprintf("-%02d:%02d", mins, secs)
		} else {
			return fmt.aprintf("%02d:%02d", mins, secs)
		}
	}
}
