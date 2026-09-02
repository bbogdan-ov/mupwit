package mupwit

Vec2 :: [2]i32

Rect :: struct {
	x, y:          i32,
	width, height: i32,
}

Color :: distinct [3]u8

// ------------------------------
// Rect.
// ------------------------------

rect_expand :: proc(rect: Rect, padding: Vec2) -> Rect {
	rect := rect
	rect.x -= padding.x
	rect.y -= padding.y
	rect.width += padding.x * 2
	rect.height += padding.y * 2
	return rect
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

color_to_f64 :: proc(color: Color) -> [3]f64 {
	f := cast([3]f64)color
	f.r /= 255
	f.g /= 255
	f.b /= 255
	return f
}
