package ui

import rlgl "rlgl"

WHITE :: Color{255, 255, 255, 255}
BLACK :: Color{0, 0, 0, 255}
RED :: Color{255, 0, 0, 255}

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
	size:        f32,
	glyphs:      []Glyph,
	glyph_count: i32,
	texture:     Texture,
	padding:     f32,
	offset_y:    f32,
}

Glyph :: struct {
	advance_x: f32,
	offset_x:  f32,
	offset_y:  f32,
	// Rect within the font texture
	rect:      Rect,
}

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

// "Low level" function that only places vertices into the current batch.
//
// NOTE:
// - This function does NOT begins and ends drawing of the batch.
// - Textures are still being drawn even outside of the view.
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

draw_text :: proc(
	font: Font,
	text: string,
	pos: Point,
	color: Color,
	scale: f32 = 1,
) -> (
	advance: Point,
) {
	pos := pos

	rlgl.SetTexture(font.texture.id)
	rlgl.Begin(rlgl.QUADS)

	pos.y -= font.offset_y
	advance_x: f32 = 0

	for rune, idx in text {
		glyph := font.glyphs[0] // defaults to null char
		if i32(rune) < font.glyph_count {
			glyph = font.glyphs[rune]
		}

		glyph_pos := Point{pos.x + advance_x, pos.y}
		next_x := (pos.x - window.text_trunc_x) + advance_x + glyph.advance_x * 2 * scale

		// NOTE: multiplying glyph width by 2 to look two glyphs ahead
		if window.text_trunc_width > 0 && next_x > window.text_trunc_width {
			// Don't draw anything if only one character is fitting.
			if idx == 0 do break

			glyph = font.glyphs['…']
			advance_x += _draw_glyph(font, glyph, glyph_pos, scale, color)
			break
		}

		advance_x += _draw_glyph(font, glyph, glyph_pos, scale, color)
	}

	rlgl.End()

	return {advance_x, font.size * scale}
}

@(private)
_draw_glyph :: #force_inline proc(
	font: Font,
	glyph: Glyph,
	pos: Point,
	scale: f32,
	color: Color,
) -> (
	advance_x: f32,
) {
	source := glyph.rect
	source.width += font.padding
	dest := Rect {
		pos.x + glyph.offset_x * scale,
		pos.y + glyph.offset_y * scale,
		source.width * scale,
		source.height * scale,
	}
	draw_texture_impl(font.texture, source, dest, color)

	return glyph.advance_x * scale
}

measure_text :: proc(font: Font, text: string, scale: f32 = 1) -> (size: Point) {
	for rune in text {
		glyph := font.glyphs[0] // defaults to null char
		if i32(rune) < font.glyph_count {
			glyph = font.glyphs[rune]
		}

		size.x += f32(glyph.advance_x) * scale
	}

	size.y = f32(font.size)
	return
}

begin_scissor :: #force_inline proc(rect: Rect) {
	rlgl.DrawRenderBatchActive()
	rlgl.EnableScissorTest()
	rlgl.Scissor(i32(rect.x), i32(rect.y), i32(rect.width), i32(rect.height))
}
end_scissor :: #force_inline proc() {
	rlgl.DrawRenderBatchActive()
	rlgl.DisableScissorTest()
}

begin_text_truncate :: #force_inline proc(x: f32, width: f32) {
	assert(width > 0)
	window.text_trunc_x = x
	window.text_trunc_width = width
}
end_text_truncate :: #force_inline proc() {
	// NOTE: we leave `text_trunc_width` as is because we don't care.
	window.text_trunc_width = 0
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
