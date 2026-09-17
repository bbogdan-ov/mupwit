package ui

import "base:intrinsics"
import "core:math"
import "core:strings"

Seconds :: f32

Vec2 :: [2]i32

Rect :: struct {
	x, y:          i32,
	width, height: i32,
}

Color :: distinct [4]u8

// ------------------------------
// Rect.
// ------------------------------

rect_pos :: proc(rect: Rect) -> Vec2 {
	return {rect.x, rect.y}
}
rect_size :: proc(rect: Rect) -> Vec2 {
	return {rect.width, rect.height}
}
rect_center :: proc(rect: Rect) -> Vec2 {
	return rect_pos(rect) + rect_size(rect) / 2
}

rect_center_inside :: proc(rect, inside: Rect) -> Rect {
	rect := rect
	rect.x = inside.x + inside.width / 2 - rect.width / 2
	rect.y = inside.y + inside.height / 2 - rect.height / 2
	return rect
}

pad :: proc(rect: Rect, padding: Vec2) -> Rect {
	rect := rect
	rect.x += padding.x
	rect.y += padding.y
	rect.width -= padding.x * 2
	rect.height -= padding.y * 2
	return rect
}
pad_l :: proc(rect: Rect, padding: i32) -> Rect {
	rect := rect
	rect.x += padding
	rect.width -= padding
	return rect
}
pad_t :: proc(rect: Rect, padding: i32) -> Rect {
	rect := rect
	rect.y += padding
	rect.height -= padding
	return rect
}
pad_r :: proc(rect: Rect, padding: i32) -> Rect {
	rect := rect
	rect.width -= padding
	return rect
}
pad_b :: proc(rect: Rect, padding: i32) -> Rect {
	rect := rect
	rect.height -= padding
	return rect
}

point_rect_overlap :: proc(v: Vec2, rect: Rect) -> bool {
	return(
		v.x >= rect.x &&
		v.y >= rect.y &&
		v.x < rect.x + rect.width &&
		v.y < rect.y + rect.height \
	)
}

rect_rect_overlap :: proc(a, b: Rect) -> bool {
	return(
		a.x + a.width >= b.x &&
		a.y + a.height >= b.y &&
		a.x < b.x + b.width &&
		a.y < b.y + b.height \
	)
}

overlap :: proc {
	point_rect_overlap,
	rect_rect_overlap,
}

// ------------------------------
// Color.
// ------------------------------

color_hex :: proc(hex: u32) -> Color {
	c: Color
	c.r = u8((hex & 0xff0000) >> 16)
	c.g = u8((hex & 0x00ff00) >> 8)
	c.b = u8((hex & 0x0000ff) >> 0)
	return c
}

color_to_f64 :: proc(color: Color) -> [4]f64 {
	f: [4]f64
	f.r = f64(color.r) / 255
	f.g = f64(color.g) / 255
	f.b = f64(color.b) / 255
	f.a = f64(color.a) / 255
	return f
}

// ------------------------------
// Values.
// ------------------------------

is_almost_zero :: #force_inline proc "contextless" (v: f32) -> bool {
	return abs(v) <= math.F32_EPSILON
}

within :: #force_inline proc "contextless" (
	v: $T,
	from, to: T,
) -> bool where intrinsics.type_is_ordered(T) {
	return from <= v && v < to
}

range_unflip :: #force_inline proc "contextless" (
	start, end: $T,
) -> (
	T,
	T,
) where intrinsics.type_is_ordered(T) {
	if start > end {
		return end, start
	} else {
		return start, end
	}
}

// Returns and updated index of some element in some list that has been reordered.
shifted_index :: proc(index: $T, from, to: T) -> T where intrinsics.type_is_numeric(T) {
	switch {
	case from == to:
		return index
	case index == from:
		return to
	case from <= index && index <= to:
		return index - 1
	case to <= index && index <= from:
		return index + 1
	case:
		return index
	}
}

// ------------------------------
// Strings.
// ------------------------------

to_cstr :: #force_inline proc(s: string) -> cstring {
	return strings.clone_to_cstring(s, context.temp_allocator)
}

// ------------------------------
// Slices.
// ------------------------------

// Moves an element from one index to another within a slice.
// Returns the range of the elements of the slice that has been shifted.
slice_reorder :: proc(slice: []$T, from, to: int) -> (start, end: int) {
	el := slice[from]

	start, end = from, to
	if start < end {
		copy(slice[start:end], slice[start + 1:end + 1])
	} else if start > end {
		start, end = end + 1, start + 1
		copy(slice[start:end], slice[start - 1:end - 1])
	}

	slice[to] = el
	return
}
