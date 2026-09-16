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

rect_expand :: proc(rect: Rect, padding: Vec2) -> Rect {
	rect := rect
	rect.x -= padding.x
	rect.y -= padding.y
	rect.width += padding.x * 2
	rect.height += padding.y * 2
	return rect
}

cut_left :: proc(rect: Rect, padding: i32) -> Rect {
	rect := rect
	rect.x += padding
	rect.width -= padding
	return rect
}
cut_top :: proc(rect: Rect, padding: i32) -> Rect {
	rect := rect
	rect.y += padding
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

overlap :: proc {
	point_rect_overlap,
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

// ------------------------------
// Strings.
// ------------------------------

to_cstr :: #force_inline proc(s: string) -> cstring {
	return strings.clone_to_cstring(s, context.temp_allocator)
}
