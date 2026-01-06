package util

import "core:mem"
import "core:strings"

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
