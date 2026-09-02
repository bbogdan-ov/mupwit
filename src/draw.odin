package mupwit

import "base:runtime"
import "lib:cairo"

PIXEL_SIZE :: 4

ICON_WIDTH :: 16
ICON_HEIGHT :: 16

// Drawing context.
Context :: struct {
	using cr: ^cairo.cairo_t,
	surface:  ^cairo.surface_t,
	view:     Rect, // Currenct visible rect.
}

Surface_Info :: struct {
	width, height: i32,
	data:          []u8,
}

Icon :: enum {
	Bar = 0,
	Play,
	Pause,
	Previous,
	Next,
	Small_Arrow_Right,
	Disk,
}

draw_icon :: proc(ctx: ^Context, icon: Icon, pos: Vec2, color: Color) {
	set_source_color(ctx, color)
	cairo.mask_surface(ctx, state.image_icons[icon], f64(pos.x), f64(pos.y))
}

draw_box :: proc(ctx: ^Context, rect: Rect, color: Color) {
	if !_should_draw_rect(ctx, rect) do return

	info := surface_info(ctx.surface)
	rect := rect_expand(rect, 1)

	left := rect.x + 1
	right := rect.x + rect.width - 1
	top := rect.y + 1
	bottom := rect.y + rect.height - 1

	_put_line_v(info, rect.x, top, bottom, color) // left
	_put_line_h(info, left, right, rect.y, color) // top
	_put_line_v(info, rect.x + rect.width, top, bottom, color) // right
	_put_line_h(info, left, right, rect.y + rect.height, color) // bottom
}

draw_box_bulgy :: proc(ctx: ^Context, rect: Rect, color: Color) {
	if !_should_draw_rect(ctx, rect) do return

	info := surface_info(ctx.surface)
	rect := rect_expand(rect, 1)

	left := rect.x + 1
	right := rect.x + rect.width - 1
	top := rect.y + 1
	bottom := rect.y + rect.height + 1

	_put_line_v(info, rect.x, top, bottom, color) // left
	_put_line_h(info, left, right, rect.y, color) // top
	_put_line_v(info, rect.x + rect.width, top, bottom, color) // right

	// Thick line at the bottom to make the box look bulgy.
	for y in 0 ..< i32(3) {
		_put_line_h(info, left, right, rect.y + rect.height + y, color)
	}

	// "Rounded" corners at the bottom.
	_put_pixel_bound_check(info, {rect.x + 1, rect.y + rect.height - 1}, color)
	_put_pixel_bound_check(info, {rect.x + rect.width - 1, rect.y + rect.height - 1}, color)
}

draw_box_rounded :: proc(ctx: ^Context, rect: Rect, color: Color) {
	if !_should_draw_rect(ctx, rect) do return

	info := surface_info(ctx.surface)
	rect := rect_expand(rect, 1)

	left := rect.x + 2
	right := rect.x + rect.width - 2
	top := rect.y + 2
	bottom := rect.y + rect.height - 2

	_put_line_v(info, rect.x, top, bottom, color) // left
	_put_line_h(info, left, right, rect.y, color) // top
	_put_line_v(info, rect.x + rect.width, top, bottom, color) // right
	_put_line_h(info, left, right, rect.y + rect.height, color) // bottom

	_put_pixel_bound_check(info, {rect.x + 1, rect.y + 1}, color) // left-top
	_put_pixel_bound_check(info, {rect.x + rect.width - 1, rect.y + 1}, color) // right-top
	_put_pixel_bound_check(info, {rect.x + rect.width - 1, rect.y + rect.height - 1}, color) // right-bottom
	_put_pixel_bound_check(info, {rect.x + 1, rect.y + rect.height - 1}, color) // left-bottom
}

draw_box_rounded_filled :: proc(ctx: ^Context, rect: Rect, color: Color) {
	if !_should_draw_rect(ctx, rect) do return

	info := surface_info(ctx.surface)
	r := rect_expand(rect, 1)

	cairo.rectangle(ctx, f64(r.x + 2), f64(r.y), f64(r.width - 4), f64(r.height)) // main rect
	cairo.rectangle(ctx, f64(r.x), f64(r.y + 2), f64(2), f64(r.height - 4)) // left edge
	cairo.rectangle(ctx, f64(r.x + r.width - 2), f64(r.y + 2), f64(2), f64(r.height - 4)) // right edge
	set_source_color(ctx, color)
	cairo.fill(ctx)

	_put_pixel_bound_check(info, {r.x + 1, r.y + 1}, color) // left-top
	_put_pixel_bound_check(info, {r.x + r.width - 2, r.y + 1}, color) // right-top
	_put_pixel_bound_check(info, {r.x + r.width - 2, r.y + r.height - 2}, color) // right-bottom
	_put_pixel_bound_check(info, {r.x + 1, r.y + r.height - 2}, color) // left-bottom
}

_should_draw_rect :: proc(ctx: ^Context, rect: Rect) -> bool {
	r := rect
	r.x -= ctx.view.x
	r.y -= ctx.view.y

	return(
		r.width > 0 &&
		r.height > 0 &&
		r.x < ctx.view.width &&
		r.y < ctx.view.height &&
		r.x + r.width >= 0 &&
		r.y + r.height >= 0 \
	)
}

_put_line_h :: proc(info: Surface_Info, left, right, y: i32, color: Color) {
	if y < 0 || info.height <= y do return
	if right < 0 do return
	if left >= info.width do return

	left := max(left, 0)
	right := min(right, info.width - 1)

	for x in left ..= right {
		_put_pixel(info, {x, y}, color)
	}
}

_put_line_v :: proc(info: Surface_Info, x, top, bottom: i32, color: Color) {
	if x < 0 || info.width <= x do return
	if bottom < 0 do return
	if top >= info.height do return

	top := max(top, 0)
	bottom := min(bottom, info.height - 1)

	for y in top ..= bottom {
		_put_pixel(info, {x, y}, color)
	}
}

_put_pixel_bound_check :: proc(info: Surface_Info, pos: Vec2, color: Color) {
	if pos.x < 0 || info.width <= pos.x do return
	if pos.y < 0 || info.height <= pos.y do return
	_put_pixel(info, pos, color)
}

_put_pixel :: proc(info: Surface_Info, pos: Vec2, color: Color) {
	i := pos.x * PIXEL_SIZE + pos.y * info.width * PIXEL_SIZE
	if i < 0 || i32(len(info.data)) <= i + PIXEL_SIZE do return
	#no_bounds_check {
		info.data[i + 0] = color.r
		info.data[i + 1] = color.g
		info.data[i + 2] = color.b
	}
}

set_source_color :: proc(cr: ^cairo.cairo_t, color: Color) {
	f := color_to_f64(color)
	cairo.set_source_rgb(cr, f.r, f.g, f.b)
}

surface_info :: proc(surface: ^cairo.surface_t) -> Surface_Info {
	width := cairo.image_surface_get_width(surface)
	height := cairo.image_surface_get_height(surface)

	data := transmute([]u8)runtime.Raw_Slice {
		data = cairo.image_surface_get_data(surface),
		len = int(width * height * PIXEL_SIZE),
	}

	return {width, height, data}
}
