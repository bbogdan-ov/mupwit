package mupwit

import "base:runtime"

import "lib:cairo"
import win "lib:my_window"

State :: struct {
	px, py:            i32,

	// Assets.
	font_library:      win.Font_Library,
	font_kapli:        Font,
	image_icons_sheet: ^cairo.surface_t,
	image_icons:       [Icon]^cairo.surface_t,
}

state: State

main :: proc() {
	context.logger = make_logger()

	window := win.window_new(WINDOW_WIDTH, WINDOW_HEIGHT)
	assert(window != nil) // TODO: handle error.

	win.window_set_resizable(window, false)
	win.window_set_draw_callback(window, _window_draw)
	win.window_set_pointer_motion_callback(window, _window_on_pointer_motion)

	assets_load()
	defer assert_destroy()

	for win.window_should_run(window) {}

	win.window_destroy(window)
}

draw :: proc(ctx: ^Context) {
	defer free_all(context.temp_allocator)

	set_source_color(ctx, WHITE)
	cairo.paint(ctx)

	draw_box_rounded_filled(ctx, {10, 10, 60, 40}, BLACK)

	for icon, i in Icon {
		draw_icon(ctx, icon, {state.px, state.py + i32(i) * ICON_HEIGHT}, BLACK)
	}
}

_window_draw :: proc "c" (window: ^win.Window, cr: ^cairo.cairo_t, surface: ^cairo.surface_t) {
	context = runtime.default_context()
	context.logger = make_logger()

	ctx := Context {
		cr      = cr,
		surface = surface,
	}
	ctx.view.x = 0
	ctx.view.y = 0
	ctx.view.width = cairo.image_surface_get_width(surface)
	ctx.view.height = cairo.image_surface_get_height(surface)

	draw(&ctx)
}

_window_on_pointer_motion :: proc "c" (window: ^win.Window, x, y: f64) {
	state.px = i32(x)
	state.py = i32(y)
}
