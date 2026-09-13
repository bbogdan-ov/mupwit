package mupwit

import "core:log"
import "core:time"

import "lib:cairo"
import win "lib:my_window"
import "lib:ui"

State :: struct {
	player:     Player,

	// Assets.
	font_kapli: ui.Font,
	icons:      ui.Sprites(Icon),
}

state: State

main :: proc() {
	context.logger = make_logger()

	window := win.window_new(WINDOW_WIDTH, WINDOW_HEIGHT)
	assert(window != nil) // TODO: handle error.

	win.window_set_resizable(window, false)
	win.window_set_frame_callback(window, _window_on_frame)
	win.window_set_draw_callback(window, _window_draw)
	win.window_set_pointer_button_callback(window, _window_on_pointer_button)
	win.window_set_pointer_motion_callback(window, _window_on_pointer_motion)
	win.window_set_pointer_scroll_callback(window, _window_on_pointer_scroll)

	ui.init()
	assets_load()
	player_connect()

	for win.window_should_run(window) {}

	log.info("Closing the window...")
	win.window_destroy(window)
	assets_destroy()
	ui.destroy()

	player_destroy()

	log.info("Bye")
}

update :: proc(dt: Seconds) {
	player_update(dt)

	status_ui_update()
	queue_ui_update(dt)

	ui.update()
}

draw :: proc(ctx: ^ui.Context) {
	defer free_all(context.temp_allocator)

	cairo.set_antialias(ctx, .NONE)

	// Fill background.
	ui.set_source_color(ctx, BACKGROUND)
	cairo.paint(ctx)

	// TEMPORARY: for now all text fonts will be the same.
	ui.set_font(ctx, state.font_kapli, 16)

	queue_ui_draw(ctx)
	status_ui_draw(ctx)
}

_window_draw :: proc "c" (window: ^win.Window, cr: ^cairo.cairo_t, surface: ^cairo.surface_t) {
	context = make_default_context()

	ctx: ui.Context
	ctx.cr = cr
	ctx.surface = surface
	ctx.screen = ui.surface_rect(surface)
	ctx.container.rect = ctx.screen

	draw(&ctx)
}

_window_on_frame :: proc "c" (window: ^win.Window) {
	context = make_default_context()

	now := time.now()

	@(static) start: time.Time
	if start._nsec == 0 do start = now

	delta := time.diff(start, now)
	start = now

	dt := Seconds(time.duration_seconds(delta))
	update(dt)
}

_window_on_pointer_button :: proc "c" (
	window: ^win.Window,
	button: win.Button,
	button_state: win.Button_State,
) {
	ui.on_pointer_button(button, button_state)
}
_window_on_pointer_motion :: proc "c" (window: ^win.Window, x, y: f64) {
	ui.on_pointer_motion({i32(x), i32(y)})
}
_window_on_pointer_scroll :: proc "c" (window: ^win.Window, x, y: f64, touchpad: bool) {
	context = make_default_context()
	scroll := f32(y)

	queue_ui_on_scroll(scroll, touchpad)
}
