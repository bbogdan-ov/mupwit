package mpd

import "core:strings"
import "core:testing"
import "core:unicode"
import "core:unicode/utf8"

Parser :: struct {
	s:      string,
	offset: int,
}

Pair :: struct {
	field: string,
	value: string,
}

parser_make :: proc(s: string) -> (p: Parser) {
	p.s = s
	return
}

// Deleted string of a parser if it was allocated on the heap.
parser_destroy :: proc(p: Parser, allocator := context.allocator) {
	delete(p.s, allocator)
}

parser_next_named_pair :: proc(p: ^Parser, field: string) -> (value: string, ok: bool) {
	for pair in parser_next_pair(p) {
		if pair.field == field {
			return pair.value, true
		}
	}
	return "", false
}

// Parse next `<field>: <value>` pair.
parser_next_pair :: proc(p: ^Parser) -> (pair: Pair, ok: bool) {
	parser_skip_spaces(p)

	pair.field = parser_next_field(p) or_return
	if pair.field == "OK" {
		p.offset = len(p.s)
		return {}, false
	}

	pair.value = parser_next_value(p) or_return

	return pair, true
}

// Parse next `<number>:<kind>: <path>`
parser_next_queue_song :: proc(
	p: ^Parser,
) -> (
	number: string,
	kind: string,
	path: string,
	ok: bool,
) {
	number = parser_next_field(p) or_return
	kind = parser_next_field(p) or_return
	path = parser_next_value(p) or_return
	ok = true
	return
}

// Parse anything untill ':'.
parser_next_field :: proc(p: ^Parser) -> (field: string, ok: bool) {
	start := p.offset
	end := p.offset

	for rune in parser_cur_rune(p) {
		defer parser_advance(p, rune)

		end = p.offset

		if rune == '\n' do return "", false
		if rune == ':' do break
	}

	if start >= end do return "", false
	return strings.trim_space(p.s[start:end]), true
}

// Parse anything untill newline.
parser_next_value :: proc(p: ^Parser) -> (value: string, ok: bool) {
	start := p.offset
	end := p.offset

	for rune in parser_cur_rune(p) {
		defer parser_advance(p, rune)

		end = p.offset
		if rune == '\n' do break
	}

	if start >= end do return "", false
	return strings.trim_space(p.s[start:end]), true
}

parser_skip_spaces :: proc(p: ^Parser) {
	for rune in parser_cur_rune(p) {
		if !unicode.is_space(rune) do break
		parser_advance(p, rune)
	}
}

parser_cur_rune :: proc(p: ^Parser) -> (rune: rune, ok: bool) {
	if p.offset >= len(p.s) do return utf8.RUNE_ERROR, false

	rune = utf8.rune_at(p.s[p.offset:], 0)
	return rune, true
}

parser_advance :: proc(p: ^Parser, rune: rune) {
	p.offset += utf8.rune_size(rune)
}

@(test)
parser_test :: proc(t: ^testing.T) {
	TEXT :: `
field: value
another: field with  value 
  and this :  one  
OK
this should: be ignored`

	p := parser_make(TEXT)

	next :: proc(t: ^testing.T, p: ^Parser, expect: Pair, loc := #caller_location) -> bool {
		pair, ok := parser_next_pair(p)
		testing.expect(t, ok, loc = loc) or_return
		testing.expectf(t, pair == expect, "%v != %v", pair, expect, loc = loc) or_return
		return true
	}

	next(t, &p, {"field", "value"})
	next(t, &p, {"another", "field with  value"})
	next(t, &p, {"and this", "one"})

	_, ok := parser_next_pair(&p)
	testing.expect(t, !ok)
}
