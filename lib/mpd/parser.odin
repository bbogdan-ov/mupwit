package mpd

import "base:intrinsics"
import "core:log"
import "core:reflect"
import "core:strconv"
import "core:strings"
import "core:testing"
import "core:unicode"
import "core:unicode/utf8"

_ :: reflect

Parser :: struct {
	s:      string,
	offset: int,
}

Pair :: struct {
	key:   string,
	value: string,
}

Parse_Error :: enum {
	None = 0,
	Parse_Value,
	Unsupported_Type,
}

parser_make :: proc(s: string) -> (p: Parser) {
	p.s = s
	return
}

// Deleted string of a parser if it was allocated on the heap.
parser_destroy :: proc(p: Parser, allocator := context.allocator) {
	delete(p.s, allocator)
}

parser_next_named_pair :: proc(p: ^Parser, key: string) -> (value: string, ok: bool) {
	for pair in parser_next_pair(p) {
		if pair.key == key {
			return pair.value, true
		}
	}
	return "", false
}

// Parse next `<key>: <value>` pair.
parser_next_pair :: proc(p: ^Parser) -> (pair: Pair, ok: bool) {
	parser_skip_spaces(p)

	pair.key = parser_next_key(p) or_return
	if pair.key == "OK" {
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
	number = parser_next_key(p) or_return
	kind = parser_next_key(p) or_return
	path = parser_next_value(p) or_return
	ok = true
	return
}

// Parse anything untill ':'.
parser_next_key :: proc(p: ^Parser) -> (field: string, ok: bool) {
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

// Parse next sequence of `changed: <subsystem>`.
parser_next_changes :: proc(p: ^Parser) -> (changes: Changes, ok: bool) {
	for pair in parser_next_pair(p) {
		if pair.key != "changed" do continue

		c := parse_enum(Change, pair.value) or_return
		log.info(pair.value, c)
		changes |= {c}
	}
	return changes, true
}

@(require_results)
parser_next_struct :: proc(
	$T: typeid,
	p: ^Parser,
	loc := #caller_location,
) -> (
	strct: T,
	err: Parse_Error,
) {
	err = parser_next_struct_any(p, strct, loc)
	return
}

// Parse next struct from `<key>: <value>` sequence.
@(require_results)
parser_next_struct_any :: proc(
	p: ^Parser,
	strct: any,
	loc := #caller_location,
) -> (
	err: Parse_Error,
) {
	for pair in parser_next_pair(p) {
		target_field: any
		field_name: string
		field_alias: string

		for field in reflect.struct_fields_zipped(strct.id) {
			field_name = field.name
			field_alias = field.name
			if field.tag != "" do field_alias = string(field.tag)

			if pair.key == field_alias {
				target_field = reflect.struct_field_value(strct, field)
				break
			}
		}

		if target_field == nil do continue

		err = field_parse(target_field, pair.value)
		if err != nil {
			MSG :: "MPD: Failed to parse: %v\n\tfield = %T.%s: %T %q\n\tpair = %v"
			log.errorf(
				MSG,
				err,
				strct,
				field_name,
				target_field,
				field_alias,
				pair,
				location = loc,
			)
			return err
		}
	}

	return nil
}

@(require_results)
field_parse :: proc(field: any, s: string) -> (err: Parse_Error) {
	sc :: strconv
	type_base_type :: intrinsics.type_base_type

	// To not forget to update parsing implemention.
	#assert(type_base_type(Song_Pos) == int)
	#assert(type_base_type(Song_Id) == int)
	#assert(type_base_type(Seconds) == f32)

	ok: bool
	switch &v in field {
	case nil:
		ok = true
	case bool:
		v = s == "1"
		ok = true
	case int:
		v, ok = sc.parse_int(s)
	case f32:
		v, ok = sc.parse_f32(s)

	case Song_Id:
		v = Song_Id(sc.parse_int(s) or_break)
		ok = true
	case Song_Pos:
		v = Song_Pos(sc.parse_int(s) or_break)
		ok = true
	case Seconds:
		v = Seconds(sc.parse_f32(s) or_break)
		ok = true
	case Play_State:
		v, ok = parse_enum(Play_State, s)
	case Single_State:
		v, ok = parse_enum(Single_State, s)

	case:
		return .Unsupported_Type
	}

	if !ok do return .Parse_Value
	return nil
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

// Parses an enum from name of one of its variants.
@(require_results)
parse_enum :: proc(
	$T: typeid,
	name: string,
) -> (
	value: T,
	ok: bool,
) where intrinsics.type_is_enum(T) {
	for variant in reflect.enum_fields_zipped(T) {
		switch {
		case strings.equal_fold(variant.name, name):
			fallthrough
		case variant.name == "Off" && name == "0":
			fallthrough
		case variant.name == "On" && name == "1":
			return T(variant.value), true
		}
	}
	return {}, false
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
