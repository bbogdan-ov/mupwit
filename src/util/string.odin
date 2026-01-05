package util

import "core:strings"

// Split string exactly into two parts separated by the separator `sep`
//
// `ok` is false when there is no `sep` in the string
split_once :: proc(s: string, sep: rune) -> (left, right: string, ok: bool) {
	idx := strings.index_rune(s, sep)
	if idx < 0 do return "", "", false

	// +1 to exclude the separator
	return s[:idx], s[idx + 1:], true
}

maybe_str_delete :: proc(str: Maybe(string)) {
	switch s in str {
	case nil:
	case string:
		delete(s)
	}
}
