package ui

import rlgl "rlgl"

draw_rect :: proc(rect: Rect, color: Color) {
	ww := f32(window.width)
	wh := f32(window.height)
	left: f32 = rect.x / ww * 2 - 1
	top: f32 = 1 - rect.y / wh * 2
	right: f32 = (rect.x + rect.width) * 2 / ww - 1
	bottom: f32 = 1 - (rect.y + rect.height) * 2 / wh

	rlgl.Begin(rlgl.TRIANGLES)
	{
		rlgl.Color4ub(color.r, color.g, color.b, color.a)

		rlgl.Vertex2f(left, bottom)
		rlgl.Vertex2f(right, bottom)
		rlgl.Vertex2f(left, top)

		rlgl.Vertex2f(left, top)
		rlgl.Vertex2f(right, bottom)
		rlgl.Vertex2f(right, top)
	}
	rlgl.End()
}

draw_texture :: #force_inline proc(texture: Texture, pos: Point, tint := WHITE) {
	source := Rect{0, 0, f32(texture.width), f32(texture.height)}
	dest := Rect{pos.x, pos.y, source.width, source.height}
	draw_texture_ex(texture, source, dest, tint)
}

draw_texture_ex :: proc(texture: Texture, source: Rect, dest: Rect, tint := WHITE) {
	rlgl.SetTexture(texture.id)
	rlgl.Begin(rlgl.QUADS)
	draw_texture_impl(texture, source, dest, tint)
	rlgl.End()
	rlgl.SetTexture(0)
}

// NOTE: textures are still being drawn even outside of the view.
draw_texture_impl :: proc(texture: Texture, source: Rect, dest: Rect, tint := WHITE) {
	if source.width <= 0 || source.height <= 0 || dest.width <= 0 || dest.height <= 0 {
		return
	}

	tw := f32(texture.width)
	th := f32(texture.height)
	ww := f32(window.width)
	wh := f32(window.height)

	left: f32 = dest.x / ww * 2 - 1
	top: f32 = 1 - dest.y / wh * 2
	right: f32 = (dest.x + dest.width) * 2 / ww - 1
	bottom: f32 = 1 - (dest.y + dest.height) * 2 / wh

	rlgl.Color4ub(tint.r, tint.g, tint.b, tint.a)

	rlgl.TexCoord2f(source.x / tw, (source.y + source.height) / th)
	rlgl.Vertex2f(left, bottom)

	rlgl.TexCoord2f((source.x + source.width) / tw, (source.y + source.height) / th)
	rlgl.Vertex2f(right, bottom)

	rlgl.TexCoord2f((source.x + source.width) / tw, source.y / th)
	rlgl.Vertex2f(right, top)

	rlgl.TexCoord2f(source.x / tw, source.y / th)
	rlgl.Vertex2f(left, top)
}

draw_texture_anim :: proc(
	texture: Texture,
	pos: Point,
	frame: [2]i32,
	frames: [2]i32,
	tint := WHITE,
) {
	frame_width := f32(texture.width / frames.x)
	frame_height := f32(texture.height / frames.y)
	source := Rect {
		f32(frame.x) * frame_width,
		f32(frame.y) * frame_height,
		frame_width,
		frame_height,
	}
	dest := Rect{pos.x, pos.y, frame_width, frame_height}

	draw_texture_ex(texture, source, dest, tint)
}

draw_text_font :: proc(
	font: Font,
	text: string,
	pos: Point,
	color := THEME_BLACK,
	scale: f32 = 1,
) -> (
	size: f32,
) {
	// Glyph padding
	PADDING :: 1

	advance_x: f32 = 0

	rlgl.SetTexture(font.texture.id)
	rlgl.Begin(rlgl.QUADS)

	for rune in text {
		glyph := font.glyphs[0] // defaults to null char
		if i32(rune) < font.glyph_count {
			glyph = font.glyphs[rune]
		}

		dest := Rect {
			pos.x + f32(glyph.offset_x) + advance_x,
			pos.y + f32(glyph.offset_y),
			(glyph.rect.width + PADDING) * scale,
			glyph.rect.height * scale,
		}
		source := Rect{glyph.rect.x, glyph.rect.y, glyph.rect.width + PADDING, glyph.rect.height}
		draw_texture_impl(font.texture, source, dest, color)
		advance_x += f32(glyph.advance_x) * scale
	}

	rlgl.End()
	return f32(font.size) * scale
}

draw_text :: #force_inline proc(
	text: string,
	pos: Point,
	color := THEME_BLACK,
	scale: f32 = 1,
) -> (
	size: f32,
) {
	return draw_text_font(assets.normal_font, text, pos, color, scale)
}
draw_italic_text :: #force_inline proc(
	text: string,
	pos: Point,
	color := THEME_BLACK,
	scale: f32 = 1,
) -> (
	size: f32,
) {
	return draw_text_font(assets.italic_font, text, pos, color, scale)
}

draw_box :: proc(box: Box, rect: Rect, color := THEME_BLACK) {
	FRAME_WIDTH :: 18
	FRAME_HEIGHT :: 18
	// Padding - width and height of each segment in the 9-slice texture
	P :: 6

	source := Rect{FRAME_WIDTH * f32(box), 0, FRAME_WIDTH, FRAME_HEIGHT}
	sx := source.x
	sy := source.y
	sw := source.width
	sh := source.height

	rx := rect.x - P / 2
	ry := rect.y - P / 2
	rw := rect.width + P
	rh := rect.height + P

	rlgl.SetTexture(assets.boxes.id)
	rlgl.Begin(rlgl.QUADS)

	// Top left corner
	draw_texture_impl(assets.boxes, {sx, sy, P, P}, {rx, ry, P, P}, tint = color)

	// Top edge
	draw_texture_impl(
		assets.boxes,
		{sx + P, sy, sw - P * 2, P},
		{rx + P, ry, rw - P * 2, P},
		tint = color,
	)

	// Top right corner
	draw_texture_impl(assets.boxes, {sx + sw - P, sy, P, P}, {rx + rw - P, ry, P, P}, tint = color)

	// Right edge
	draw_texture_impl(
		assets.boxes,
		{sx + sw - P, sy + P, P, sh - P * 2},
		{rx + rw - P, ry + P, P, rh - P * 2},
		tint = color,
	)

	// Bottom right corner
	draw_texture_impl(
		assets.boxes,
		{sx + sw - P, sy + sh - P, P, P},
		{rx + rw - P, ry + rh - P, P, P},
		tint = color,
	)

	// Bottom edge
	draw_texture_impl(
		assets.boxes,
		{sx + P, sy + sh - P, sw - P * 2, P},
		{rx + P, ry + rh - P, rw - P * 2, P},
		tint = color,
	)

	// Bottom left corner
	draw_texture_impl(assets.boxes, {sx, sy + sh - P, P, P}, {rx, ry + rh - P, P, P}, tint = color)

	// Left edge
	draw_texture_impl(
		assets.boxes,
		{sx, sy + P, P, sh - P * 2},
		{rx, ry + P, P, rh - P * 2},
		tint = color,
	)

	// Middle
	if box == .Filled_Rounded || box == .Filled_Normal {
		draw_texture_impl(
			assets.boxes,
			{sx + P, sy + P, sw - P * 2, sh - P * 2},
			{rx + P, ry + P, rw - P * 2, rh - P * 2},
			tint = color,
		)
	}

	rlgl.End()
}

draw_icon :: proc(icon: Icon, pos: Point, color := THEME_BLACK) {
	panic("TODO:")
	// FRAME_WIDTH :: 16
	// FRAME_HEIGHT :: 16
	//
	// source := rl.Rectangle{FRAME_WIDTH * f32(icon), 0, FRAME_WIDTH, FRAME_HEIGHT}
	// dest := rl.Rectangle{pos.x, pos.y, FRAME_WIDTH, FRAME_HEIGHT}
	// rl.DrawTexturePro(assets.icons, source, dest, {}, 0, rl.Color(color))
}

load_texture :: #force_inline proc(
	pixels: []byte,
	width, height: i32,
	format: rlgl.Pixel_Format,
	mipmaps: i32,
) -> Texture {
	id := rlgl.LoadTexture(raw_data(pixels), width, height, format, mipmaps)
	if id <= 0 { /* TODO: log failure message */}
	return Texture{id, width, height}
}

unload_texture :: #force_inline proc(texture: Texture) {
	rlgl.UnloadTexture(texture.id)
}

unload_font :: #force_inline proc(font: Font) {
	// NOTE: do not free the `glyphs` array because it is always static in this project.
	// Glyphs info is always generated at compile-time (see build_src/build.odin).
	unload_texture(font.texture)
}
