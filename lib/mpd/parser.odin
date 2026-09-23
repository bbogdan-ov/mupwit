#+vet explicit-allocators

package mpd

import "base:intrinsics"
import "core:fmt"
import "core:log"
import "core:reflect"
import "core:strconv"
import "core:strings"
import "core:testing"
import "core:unicode/utf8"

_ :: reflect

index_byte :: strings.index_byte
trim :: strings.trim_space

Parser :: struct {
	s:                string,
	offset:           int,
	prev_line_offset: int,
	finished:         bool, // Parser stambled upon "OK".
}

Pair :: struct {
	key:   string,
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

parser_next_line :: proc(p: ^Parser) -> (line: string, found: bool) {
	if p.finished do return "", false

	start := p.offset
	end := p.offset
	p.prev_line_offset = p.offset

	for rune in parser_cur_rune(p) {
		parser_advance(p, rune)
		if rune == '\n' do break
		end = p.offset
	}

	if start <= end {
		line = trim(p.s[start:end])
		if line == "OK" do p.finished = true

		if !p.finished && p.offset >= len(p.s) {
			p.finished = true
			at := max(p.offset - 32, 0)
			log.errorf(`MPD: Parser finished without reaching "OK" at %v`, p.offset)
			log.errorf(`MPD:     Last 32 bytes: %q`, p.s[at:])
		}

		return line, true
	} else {
		return "", false
	}
}

parser_peek_next_line :: proc(p: ^Parser) -> (line: string, found: bool) {
	before := p.offset
	defer p.offset = before
	return parser_next_line(p)
}

// Parse next `<key>: <value>` pair.
parser_next_pair :: proc(p: ^Parser) -> (pair: Pair, found: bool) {
	line := parser_next_line(p) or_return

	COLON :: ':'
	COLON_SIZE :: 1

	colon := index_byte(line, COLON)
	if colon < 0 {
		return {}, false
	}

	pair.key = line[:colon]
	pair.key = trim(pair.key)
	pair.value = line[colon + COLON_SIZE:]
	pair.value = trim(pair.value)

	return pair, true
}

parser_skip_until_pair :: proc(p: ^Parser, key: string) {
	for pair in parser_next_pair(p) {
		if pair.key == key {
			parser_cancel_line(p)
			return
		}
	}
}

@(require_results)
parser_next_changes :: proc(p: ^Parser) -> (changes: Changes, found: bool) {
	if parser_will_finish(p) do return {}, false

	for pair in parser_next_pair(p) {
		if pair.key != "changed" {
			parser_cancel_line(p)
			break
		}

		c := _parse_enum(Change, pair) or_continue
		changes |= {c}
	}
	return changes, true
}

@(require_results)
parser_next_song :: proc(
	p: ^Parser,
	allocator := context.allocator,
	loc := #caller_location,
) -> (
	song: Song,
	found: bool,
) {
	if parser_will_finish(p) do return {}, false

	song.allocator = allocator

	was_file := false
	loop: for pair in parser_next_pair(p) {
		switch {
		case pair.key == "file" && was_file:
			parser_cancel_line(p)
			break loop
		case pair.key == "file":
			was_file = true
		}

		_parse_struct_field_from_pair(song, pair, song.allocator, loc)
	}

	song.duration_str = fmt.aprint(song.duration, allocator = song.allocator)

	return song, true
}

@(require_results)
parser_next_status :: proc(p: ^Parser, loc := #caller_location) -> (status: Status, found: bool) {
	if parser_will_finish(p) do return {}, false
	for pair in parser_next_pair(p) {
		// NOTE: `Status` has no strings, so it doesn't need an allocator.
		_parse_struct_field_from_pair(status, pair, allocator = {}, loc = loc)
	}
	return status, true
}

parser_next_picture_info :: proc(
	p: ^Parser,
	allocator := context.allocator,
	loc := #caller_location,
) -> (
	picture: Picture,
	found: bool,
) {
	if parser_will_finish(p) do return {}, false

	picture.allocator = allocator

	for pair in parser_next_pair(p) {
		if pair.key == "binary" {
			parser_cancel_line(p)
			break
		}

		_parse_struct_field_from_pair(picture, pair, picture.allocator, loc)
	}
	return picture, true
}

parser_next_binary :: proc(p: ^Parser, loc := #caller_location) -> (data: []u8, found: bool) {
	if parser_will_finish(p) do return {}, false

	pair := parser_next_pair(p) or_return
	if pair.key != "binary" {
		parser_cancel_line(p)
		found = false
		return
	}

	size, ok := strconv.parse_uint(pair.value)
	if !ok {
		log.errorf("MPD: Failed to parse binary size: %q", pair.value, location = loc)
		found = false
		return
	}

	data = transmute([]u8)(p.s[p.offset:][:size])
	return data, true
}

_parse_struct_field_from_pair :: proc(
	struct_: any,
	pair: Pair,
	allocator := context.allocator,
	loc := #caller_location,
) {
	// Get pointer to the field.
	value: any
	for field in reflect.struct_fields_zipped(struct_.id) {
		name := field.name if field.tag == "" else string(field.tag)
		if name == pair.key {
			value = reflect.struct_field_value(struct_, field)
		}
	}

	if value == nil do return

	type_base_type :: intrinsics.type_base_type
	sclone :: strings.clone

	// So i don't forget to update parsing implemention:
	#assert(type_base_type(Song_Index) == int)
	#assert(type_base_type(Song_Id) == int)
	#assert(type_base_type(Seconds) == f32)

	switch &v in value {
	case nil:

	case bool:
		v = pair.key == "1"

	case int:
		v = _parse_number(int, pair, loc)
	case Song_Id:
		v = Song_Id(_parse_number(int, pair, loc))
	case Song_Index:
		v = Song_Index(_parse_number(int, pair, loc))
	case Maybe(Song_Id):
		v = Song_Id(_parse_number(int, pair, loc))
	case Maybe(Song_Index):
		v = Song_Index(_parse_number(int, pair, loc))

	case f32:
		v = _parse_number(f32, pair, loc)
	case Seconds:
		v = Seconds(_parse_number(f32, pair, loc))

	case string:
		// TODO: repeating fields in a command response should be treaded as arrays.
		// Currenly only the first occurence of a field is being stored, others are ignored.
		// This also prevents memory leaks when overriding existing string.
		if len(v) > 0 do break
		v = sclone(pair.value, allocator, loc)
	case Song_File:
		if len(v) > 0 do break
		v = Song_File(sclone(pair.value, allocator, loc))

	case Play_State:
		v, _ = _parse_enum(Play_State, pair, loc)
	case Single_State:
		v, _ = _parse_enum(Single_State, pair, loc)

	case:
		panic(fmt.tprintf("Unsupported type: %T", value))
	}
}

_parse_number :: #force_inline proc($T: typeid, pair: Pair, loc := #caller_location) -> T {
	when T == int {
		n, ok := strconv.parse_int(pair.value)
	} else when T == f32 {
		n, ok := strconv.parse_f32(pair.value)
	} else {
		#panic("Unsupported type")
	}

	if !ok {
		log.errorf("MPD: Failed to parse number: %v", pair, location = loc)
		if ODIN_DEBUG do panic("Failed to parse number", loc)
	}
	return n
}

@(require_results)
_parse_enum :: proc(
	$T: typeid,
	pair: Pair,
	loc := #caller_location,
) -> (
	value: T,
	ok: bool,
) where intrinsics.type_is_enum(T) {
	name := pair.value

	for variant in reflect.enum_fields_zipped(T) {
		switch {
		case variant.name == "Off" && name == "0":
			fallthrough
		case variant.name == "On" && name == "1":
			fallthrough
		case strings.equal_fold(variant.name, name):
			return T(variant.value), true
		}
	}

	log.errorf("MPD: Failed to parse enum: %v", pair, location = loc)
	if ODIN_DEBUG do panic("Failed to parse enum", loc)
	return {}, false
}

parser_cur_rune :: proc(p: ^Parser) -> (rune: rune, ok: bool) {
	if p.offset >= len(p.s) do return utf8.RUNE_ERROR, false

	rune = utf8.rune_at(p.s[p.offset:], 0)
	return rune, true
}

// Cancel previous line scan.
parser_cancel_line :: proc(p: ^Parser) {
	p.offset = p.prev_line_offset
}

parser_advance :: proc(p: ^Parser, rune: rune) {
	p.offset += utf8.rune_size(rune)
}

parser_will_finish :: proc(p: ^Parser) -> bool {
	_, found := parser_peek_next_line(p)
	return p.finished || !found
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
