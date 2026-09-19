package ui

import "base:runtime"
import "core:strings"
import "lib:cairo"

Element_ID :: distinct uintptr

Box :: struct {
	using rect: Rect,
	padding:    Vec2,
	scroll:     f32,
}

// Drawing context.
Context :: struct {
	using cr:    ^cairo.cairo_t,
	surface:     ^cairo.surface_t,
	box:         Box, // Current box rect. Elements should adapt to this box.
	font_height: i32, // Current font height.
}

Align :: enum {
	Start = 0,
	Center,
	End,
}

@(deferred_in_out = _box_end)
begin_box :: proc(ctx: ^Context, rect: Rect, padding: Vec2 = {}, scroll: f32 = 0) -> (prev: Box) {
	prev = ctx.box
	ctx.box.rect = pad(rect, padding)
	ctx.box.padding = padding
	ctx.box.scroll = scroll
	return prev
}
_box_end :: proc(ctx: ^Context, _: Rect, _: Vec2, _: f32, prev: Box) {
	ctx.box = prev
}

@(deferred_in = _clip_end)
begin_clip :: proc(ctx: ^Context) -> bool {
	_rectangle(ctx, ctx.box)
	cairo.clip(ctx)
	return true
}
_clip_end :: proc(ctx: ^Context) {
	cairo.reset_clip(ctx)
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
	x, y := f64(pos.x), f64(pos.y)

	max_advance := ctx.box.width - (pos.x - ctx.box.x) + 1

	count: i32
	text_ext: cairo.text_extents_t
	for &glyph in glyphs {
		ext: cairo.text_extents_t
		cairo.glyph_extents(ctx, &glyph, 1, &ext)

		glyph.x += x
		glyph.y += y

		// TODO!: should replace the last char with ellipsis (...) when
		// the text is being cropped.
		if i32(text_ext.x_advance + ext.x_advance) > max_advance {
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
		// TODO!: come up with a better system to draw bold text.
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
		ext := measure_glyphs(ctx, glyphs)
		pos.x -= i32(ext.x_advance / 2)
	case .End:
		ext := measure_glyphs(ctx, glyphs)
		pos.x -= i32(ext.x_advance) - 1
	}

	ext := draw_glyphs(ctx, glyphs, pos, color, bold = bold)

	return {i32(ext.x_advance), i32(ext.height)}
}

measure_glyphs :: proc(
	cr: ^cairo.cairo_t,
	glyphs: []cairo.glyph_t,
) -> (
	ext: cairo.text_extents_t,
) {
	cairo.glyph_extents(cr, raw_data(glyphs), i32(len(glyphs)), &ext)
	return
}

text_glyphs :: proc(cr: ^cairo.cairo_t, str: string) -> []cairo.glyph_t {
	scaled_font := cairo.get_scaled_font(cr)

	glyphs: [^]cairo.glyph_t
	num_glyphs: i32
	cairo.scaled_font_text_to_glyphs(
		scaled_font = scaled_font,
		x = 0,
		y = 0,
		utf8 = strings.unsafe_string_to_cstring(str),
		utf8_len = i32(len(str)),
		glyphs = &glyphs,
		num_glyphs = &num_glyphs,
		clusters = nil,
		num_clusters = nil,
		cluster_flags = nil,
	)

	return transmute([]cairo.glyph_t)runtime.Raw_Slice{glyphs, int(num_glyphs)}
}

text_glyphs_delete :: proc(glyphs: []cairo.glyph_t) {
	cairo.glyph_free(raw_data(glyphs))
}

// ------------------------------
// Shapes.
// ------------------------------

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

draw_box :: proc(ctx: ^Context, rect: Rect, color: Color, filled := false) {
	x, y := f64(rect.x), f64(rect.y)
	w, h := f64(rect.width), f64(rect.height)

	set_source_color(ctx, color)
	cairo.set_line_width(ctx, 1)

	if w <= 3 || h <= 3 {
		cairo.rectangle(ctx, x, y, w, h)
		if filled do cairo.fill(ctx)
		else do cairo.stroke(ctx)
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

	cairo.move_to(ctx, l, y)
	cairo.line_to(ctx, r, y) // top
	cairo.line_to(ctx, x + w, t)
	cairo.line_to(ctx, x + w, b) // right
	cairo.line_to(ctx, rb, y + h)
	cairo.line_to(ctx, lb, y + h) // bottom
	cairo.line_to(ctx, x, b)
	cairo.line_to(ctx, x, t) // left
	cairo.close_path(ctx)

	if filled {
		cairo.fill(ctx)
	} else {
		cairo.stroke(ctx)
	}
}

draw_box_bulgy :: proc(ctx: ^Context, rect: Rect, color: Color) {
	x, y := f64(rect.x) + 0.5, f64(rect.y) + 0.5
	w, h := f64(rect.width - 1), f64(rect.height - 1)
	l, r := x + 1, x + w - 1
	t, b := y + 1, y + h + 2

	set_source_color(ctx, color)
	cairo.set_line_width(ctx, 1)

	cairo.move_to(ctx, x, b)
	cairo.line_to(ctx, x, t) // left
	cairo.line_to(ctx, l, y)
	cairo.line_to(ctx, r, y) // top
	cairo.line_to(ctx, x + w, t)
	cairo.line_to(ctx, x + w, b) // right

	// "Rounded" corners at the bottom.
	_pixel(ctx, x + 1, y + h - 1)
	_pixel(ctx, x + w - 1, y + h - 1)

	cairo.stroke(ctx)

	// Thick line at the bottom to make the box look bulgy.
	cairo.rectangle(ctx, l, y + h, w - 1, 3)
	cairo.fill(ctx)
}

draw_box_rounded :: proc(ctx: ^Context, rect: Rect, color: Color, filled := false) {
	x, y := f64(rect.x), f64(rect.y)
	w, h := f64(rect.width), f64(rect.height)

	set_source_color(ctx, color)
	cairo.set_line_width(ctx, 1)

	if w <= 4 || h <= 4 {
		cairo.rectangle(ctx, x, y, w, h)
		if filled do cairo.fill(ctx)
		else do cairo.stroke(ctx)
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
		cairo.move_to(ctx, l, y)
		cairo.line_to(ctx, r, y) // top
		cairo.line_to(ctx, x + w, t)
		cairo.line_to(ctx, x + w, b - 1) // right
		cairo.line_to(ctx, r - 1, y + h)
		cairo.line_to(ctx, l + 1, y + h) // bottom
		cairo.line_to(ctx, x, b - 1)
		cairo.line_to(ctx, x, t) // left
		cairo.close_path(ctx)
		cairo.fill(ctx)
	} else {
		cairo.move_to(ctx, l - 1, y)
		cairo.line_to(ctx, r, y) // top
		cairo.line_to(ctx, x + w, t)
		cairo.line_to(ctx, x + w, b - 1) // right
		cairo.line_to(ctx, r - 1, y + h)
		cairo.line_to(ctx, l, y + h) // bottom
		cairo.line_to(ctx, x, b)
		cairo.line_to(ctx, x, t - 1) // left
		cairo.close_path(ctx)
		cairo.stroke(ctx)
	}
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
