package ui

Color :: distinct [4]byte
Point :: distinct [2]f32
Rect :: struct {
	x, y, width, height: f32,
}

Texture :: struct {
	id:     u32,
	width:  i32,
	height: i32,
}

Font :: struct {
	size:        i32,
	glyphs:      []Glyph,
	glyph_count: i32,
	texture:     Texture,
}

Glyph :: struct {
	advance_x: i32,
	offset_x:  i32,
	offset_y:  i32,
	// Rect within the font texture
	rect:      Rect,
}

Box :: enum byte {
	Normal = 0,
	Rounded,
	Thick,
	Filled_Rounded,
	Filled_Normal,
}

Icon :: enum byte {
	Progress_Thumb = 0,
	Play,
	Pause,
	Previous,
	Next,
	Small_Arrow_Right,
	Disk,
}
