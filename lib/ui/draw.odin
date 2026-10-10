package ui

import "base:runtime"
import "core:slice"
import "lib:cairo"

Box :: struct {
	using rect: Rect,
	padding:    Vec2,
	scroll:     i32,
}

// Drawing context.
Context :: struct {
	using cr:    ^cairo.cairo_t,
	surface:     ^cairo.surface_t,
	box:         Box, // Current box rect. Elements should adapt to this box.
	font_height: i32, // Current font height.
	crop_text:   bool,
}

Align :: enum {
	Start = 0,
	Center,
	End,
}

Corner :: enum {
	Top_Left = 0,
	Top_Right,
	Bottom_Right,
	Bottom_Left,
}

Box_Guard :: struct {
	ctx:  ^Context,
	prev: Box,
}

@(deferred_out = end_box)
guard_box :: proc(ctx: ^Context, rect: Rect, padding: Vec2 = {}, scroll: f32 = 0) -> Box_Guard {
	return begin_box(ctx, rect, padding, scroll)
}
begin_box :: proc(ctx: ^Context, rect: Rect, padding: Vec2 = {}, scroll: f32 = 0) -> Box_Guard {
	prev := ctx.box
	ctx.box.rect = pad(rect, padding)
	ctx.box.padding = padding
	ctx.box.scroll = i32(scroll)
	return {ctx, prev}
}
end_box :: proc(guard: Box_Guard) {
	guard.ctx.box = guard.prev
}

@(deferred_in = end_clip)
guard_clip :: proc(ctx: ^Context) {
	begin_clip(ctx)
}
begin_clip :: proc(ctx: ^Context) {
	_rectangle(ctx, pad(ctx.box, -ctx.box.padding))
	cairo.clip(ctx)
}
end_clip :: proc(ctx: ^Context) {
	cairo.reset_clip(ctx)
}

@(deferred_in_out = _end_crop_text)
guard_crop_text :: proc(ctx: ^Context, crop: bool) -> (prev: bool) {
	prev = ctx.crop_text
	ctx.crop_text = crop
	return prev
}
_end_crop_text :: proc(ctx: ^Context, _, prev: bool) {
	ctx.crop_text = prev
}

// ------------------------------
// Text.
// ------------------------------

set_font :: proc(ctx: ^Context, font: ^cairo.font_face_t, size: f64) {
	cairo.set_font_face(ctx, font)
	cairo.set_font_size(ctx, size)

	ext: cairo.font_extents_t
	cairo.font_extents(ctx, &ext)
	ctx.font_height = i32(ext.ascent - ext.descent)
}

draw_glyphs :: proc(
	ctx: ^Context,
	glyphs: []cairo.glyph_t,
	pos: Vec2,
	color: Color,
	bold := false,
) -> cairo.text_extents_t {
	if len(glyphs) == 0 do return {}

	x, y := f64(pos.x), f64(pos.y)
	max_advance := ctx.box.width - (pos.x - ctx.box.x) + 1
	ellipsis_index := len(glyphs) - 1

	count: i32
	text_ext: cairo.text_extents_t
	for &glyph in glyphs[:ellipsis_index] {
		ext: cairo.text_extents_t
		cairo.glyph_extents(ctx, &glyph, 1, &ext)

		glyph.x += x
		glyph.y += y

		if ctx.crop_text && i32(text_ext.x_advance + ext.x_advance) > max_advance {
			if count <= 1 {
				count = 0
				break
			}

			// Break the loop and backpatch the last glyph to be the ellipsis char.
			glyphs[count - 1].index = glyphs[ellipsis_index].index
			break
		}

		text_ext.width += ext.width
		text_ext.x_advance += ext.x_advance
		text_ext.height = max(text_ext.height, ext.height)
		text_ext.y_advance = max(text_ext.y_advance, ext.y_advance)
		count += 1
	}

	set_source_color(ctx, color)
	cairo.show_glyphs(ctx, raw_data(glyphs), count)
	if bold {
		// TODO: come up with a better system to draw bold text.
		for &glyph in glyphs do glyph.x += 1
		cairo.show_glyphs(ctx, raw_data(glyphs), count)
	}

	return text_ext
}

// TODO: come up with a better text drawing without allocation.
// I'll probably have to implement my own font and text rendering.
draw_text :: proc(
	ctx: ^Context,
	str: string,
	pos: Vec2,
	color: Color,
	align := Align.Start,
	bold := false,
) -> (
	advance: Vec2,
) {
	pos := pos

	glyphs := text_glyphs(ctx, str)
	defer text_glyphs_delete(glyphs)

	switch align {
	case .Start:
	case .Center:
		ext := measure_glyphs(ctx, glyphs, true)
		pos.x -= i32(ext.x_advance / 2)
	case .End:
		ext := measure_glyphs(ctx, glyphs, true)
		pos.x -= i32(ext.x_advance) - 1
	}

	ext := draw_glyphs(ctx, glyphs, pos, color, bold = bold)

	return {i32(ext.x_advance), i32(ext.height)}
}

measure_glyphs :: proc(
	cr: ^cairo.cairo_t,
	glyphs: []cairo.glyph_t,
	trim_ellipsis: bool,
) -> (
	ext: cairo.text_extents_t,
) {
	if len(glyphs) == 0 do return {}
	count := i32(len(glyphs))
	// Trim the last glyph that is an ellipsis ("...") char to ignore it.
	if trim_ellipsis do count -= 1
	cairo.glyph_extents(cr, raw_data(glyphs), count, &ext)
	return
}

text_glyphs :: proc(cr: ^cairo.cairo_t, str: string) -> []cairo.glyph_t {
	runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD()

	@(static, rodata)
	ELLIPSIS := "…"

	// Append "ELLIPSIS" char at the end of the string.
	buf := make([]u8, len(str) + len(ELLIPSIS), context.temp_allocator)
	copy(buf[:len(str)], transmute([]u8)str)
	copy(buf[len(str):], transmute([]u8)ELLIPSIS)

	scaled_font := cairo.get_scaled_font(cr)

	glyphs: [^]cairo.glyph_t
	num_glyphs: i32
	cairo.scaled_font_text_to_glyphs(
		scaled_font = scaled_font,
		x = 0,
		y = 0,
		utf8 = cast(cstring)raw_data(buf),
		utf8_len = i32(len(buf)),
		glyphs = &glyphs,
		num_glyphs = &num_glyphs,
		clusters = nil,
		num_clusters = nil,
		cluster_flags = nil,
	)

	return slice.from_ptr(glyphs, int(num_glyphs))
}

text_glyphs_delete :: proc(glyphs: []cairo.glyph_t) {
	if glyphs != nil {
		cairo.glyph_free(raw_data(glyphs))
	}
}

// ------------------------------
// Shapes.
// ------------------------------

draw_surface :: proc(cr: ^cairo.cairo_t, surface: ^cairo.surface_t, pos: Vec2) {
	cairo.set_source_surface(cr, surface, f64(pos.x), f64(pos.y))
	cairo.paint(cr)
}

draw_surface_tinted :: proc(
	cr: ^cairo.cairo_t,
	surface: ^cairo.surface_t,
	pos: Vec2,
	color: Color,
) {
	set_source_color(cr, color)
	cairo.mask_surface(cr, surface, f64(pos.x), f64(pos.y))
}

draw_rect :: proc(cr: ^cairo.cairo_t, rect: Rect, color: Color) {
	_rectangle(cr, rect)
	set_source_color(cr, color)
	cairo.fill(cr)
}

draw_line_h :: proc(cr: ^cairo.cairo_t, rect: Rect, color: Color) {
	set_source_color(cr, color)
	cairo.set_line_width(cr, 1)
	cairo.move_to(cr, f64(rect.x), f64(rect.y) + 0.5)
	cairo.line_to(cr, f64(rect.x + rect.width), f64(rect.y) + 0.5)
	cairo.stroke(cr)
}

draw_box :: proc(cr: ^cairo.cairo_t, rect: Rect, color: Color, filled := false) {
	x, y := f64(rect.x), f64(rect.y)
	w, h := f64(rect.width), f64(rect.height)

	set_source_color(cr, color)
	cairo.set_line_width(cr, 1)

	if w <= 3 || h <= 3 {
		cairo.rectangle(cr, x, y, w, h)
		if filled do cairo.fill(cr)
		else do cairo.stroke(cr)
		return
	}

	if !filled {
		x += 0.5
		y += 0.5
		w -= 1
		h -= 1
	}

	l, r := x + 1, x + w - 1
	t, b := y + 1, y + h - 1
	lb, rb := l, r

	if filled {
		b -= 1
		rb -= 1
		lb += 1
	}

	cairo.move_to(cr, l, y)
	cairo.line_to(cr, r, y) // top
	cairo.line_to(cr, x + w, t)
	cairo.line_to(cr, x + w, b) // right
	cairo.line_to(cr, rb, y + h)
	cairo.line_to(cr, lb, y + h) // bottom
	cairo.line_to(cr, x, b)
	cairo.line_to(cr, x, t) // left
	cairo.close_path(cr)

	if filled {
		cairo.fill(cr)
	} else {
		cairo.stroke(cr)
	}
}

draw_box_bulgy :: proc(cr: ^cairo.cairo_t, rect: Rect, color: Color) {
	x, y := f64(rect.x) + 0.5, f64(rect.y) + 0.5
	w, h := f64(rect.width - 1), f64(rect.height - 1)
	l, r := x + 1, x + w - 1
	t, b := y + 1, y + h + 2

	set_source_color(cr, color)
	cairo.set_line_width(cr, 1)

	cairo.move_to(cr, x, b)
	cairo.line_to(cr, x, t) // left
	cairo.line_to(cr, l, y)
	cairo.line_to(cr, r, y) // top
	cairo.line_to(cr, x + w, t)
	cairo.line_to(cr, x + w, b) // right

	// "Rounded" corners at the bottom.
	_pixel(cr, x + 1, y + h - 1)
	_pixel(cr, x + w - 1, y + h - 1)

	cairo.stroke(cr)

	// Thick line at the bottom to make the box look bulgy.
	cairo.rectangle(cr, l, y + h, w - 1, 3)
	cairo.fill(cr)
}

draw_box_rounded :: proc(cr: ^cairo.cairo_t, rect: Rect, color: Color, filled := false) {
	x, y := f64(rect.x), f64(rect.y)
	w, h := f64(rect.width), f64(rect.height)

	set_source_color(cr, color)
	cairo.set_line_width(cr, 1)

	if w <= 4 || h <= 4 {
		cairo.rectangle(cr, x, y, w, h)
		if filled do cairo.fill(cr)
		else do cairo.stroke(cr)
		return
	}

	if !filled {
		x += 1
		y += 1
		w -= 1
		h -= 1
	}

	l, r := x + 2, x + w - 2
	t, b := y + 2, y + h - 2

	if filled {
		cairo.move_to(cr, l, y)
		cairo.line_to(cr, r, y) // top
		cairo.line_to(cr, x + w, t)
		cairo.line_to(cr, x + w, b - 1) // right
		cairo.line_to(cr, r - 1, y + h)
		cairo.line_to(cr, l + 1, y + h) // bottom
		cairo.line_to(cr, x, b - 1)
		cairo.line_to(cr, x, t) // left
		cairo.close_path(cr)
		cairo.fill(cr)
	} else {
		cairo.move_to(cr, l - 1, y)
		cairo.line_to(cr, r, y) // top
		cairo.line_to(cr, x + w, t)
		cairo.line_to(cr, x + w, b - 1) // right
		cairo.line_to(cr, r - 1, y + h)
		cairo.line_to(cr, l, y + h) // bottom
		cairo.line_to(cr, x, b)
		cairo.line_to(cr, x, t - 1) // left
		cairo.close_path(cr)
		cairo.stroke(cr)
	}
}

SPEECH_BUBBLE_TAIL_SIZE :: 8

draw_speech_bubble :: proc(
	cr: ^cairo.cairo_t,
	rect: Rect,
	color: Color,
	corner := Corner.Bottom_Right,
) {
	x, y := f64(rect.x), f64(rect.y)
	w, h := f64(rect.width), f64(rect.height)

	set_source_color(cr, color)
	cairo.set_line_width(cr, 1)

	if w <= 4 || h <= 4 {
		cairo.rectangle(cr, x, y, w, h)
		cairo.fill(cr)
		return
	}

	l, r := x + 2, x + w - 2
	t, b := y + 2, y + h - 2

	tail: f64 = min(SPEECH_BUBBLE_TAIL_SIZE, w - 3)
	tail = min(tail, h - 3)

	#partial switch corner {
	case .Top_Left:
		cairo.move_to(cr, x + tail + 1, y)
		cairo.line_to(cr, r, y) // top
		cairo.line_to(cr, x + w, t)
		cairo.line_to(cr, x + w, b - 1) // right
		cairo.line_to(cr, r - 1, y + h)
		cairo.line_to(cr, l + 1, y + h) // bottom
		cairo.line_to(cr, x, b - 1)
		cairo.line_to(cr, x, y - tail + 1) // left
		cairo.line_to(cr, x + 2, y - tail + 1) // tail
	case .Bottom_Right:
		cairo.move_to(cr, l, y)
		cairo.line_to(cr, r, y) // top
		cairo.line_to(cr, x + w, t)
		cairo.line_to(cr, x + w, y + h + tail - 1) // right
		cairo.line_to(cr, x + w - 1, y + h + tail - 1) // tail
		cairo.line_to(cr, x + w - tail, y + h)
		cairo.line_to(cr, l + 1, y + h) // bottom
		cairo.line_to(cr, x, b - 1)
		cairo.line_to(cr, x, t) // left
	case:
		panic("TODO: implement other speech bubble corners.")
	}

	cairo.close_path(cr)
	cairo.fill(cr)
}

draw_box_wavy :: proc(
	cr: ^cairo.cairo_t,
	rect: Rect,
	color: Color,
	frequency: f64 = 20,
	amplitude: f64 = 2,
) {
	if frequency <= 0 {
		draw_rect(cr, rect, color)
		return
	}

	x, y := f64(rect.x), f64(rect.y)
	w, h := f64(rect.width), f64(rect.height)

	cairo.move_to(cr, x + w, y + h)
	cairo.line_to(cr, x + w, y)
	cairo.line_to(cr, x, y)
	cairo.line_to(cr, x, y + h)

	freq := w / (frequency * 2)
	freq2 := freq / 2

	px := x
	py := y + h
	right := x + w
	
		// odinfmt:disable
	i := 0
	for ; px < right; px += freq {
		if px + freq > right do break

		start, end: f64
		if i % 2 == 0 {
			start, end = 0, amplitude
		} else {
			start, end = amplitude, 0
		}

		cairo.curve_to(
			cr,
			px + freq2,        py - start,
			px + freq - freq2, py - end,
			px + freq,         py - end,
		)
		i += 1
	}
		// odinfmt:enable

	cairo.close_path(cr)

	set_source_color(cr, color)
	cairo.fill(cr)
}

_rectangle :: proc(cr: ^cairo.cairo_t, rect: Rect) {
	cairo.rectangle(cr, f64(rect.x), f64(rect.y), f64(rect.width), f64(rect.height))
}

_pixel :: proc(cr: ^cairo.cairo_t, x, y: f64) {
	cairo.move_to(cr, x, y)
	cairo.line_to(cr, x, y + 1)
}

// ------------------------------
// Utils.
// ------------------------------

set_source_color :: proc(cr: ^cairo.cairo_t, color: Color) {
	f := color_to_f64(color)
	cairo.set_source_rgba(cr, f.r, f.g, f.b, f.a)
}

surface_rect :: proc(surface: ^cairo.surface_t) -> Rect {
	return {0, 0, cairo.image_surface_get_width(surface), cairo.image_surface_get_height(surface)}
}
