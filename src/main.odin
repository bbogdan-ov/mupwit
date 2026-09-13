package mupwit

import "core:log"
import "core:time"

import "lib:cairo"
import "lib:mpd"
import win "lib:my_window"

Seconds :: mpd.Seconds

State :: struct {
	player:             Player,

	// UI.
	dragging:           Maybe(Element_ID),
	drag_scroll_offset: f32,

	// Input.
	pointer:            Vec2,
	prev_pointer:       Vec2,
	press_pos:          Vec2,
	buttons:            bit_set[win.Button;u8],
	button_down:        bool,
	button_pressed:     bool,

	// Assets.
	font_library:       win.Font_Library,
	font_kapli:         Font,
	image_icons_sheet:  ^cairo.surface_t,
	image_icons:        [Icon]^cairo.surface_t,
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

	assets_load()

	player_connect()

	for win.window_should_run(window) {}

	log.info("Closing the window...")
	win.window_destroy(window)
	assets_destroy()

	player_destroy()

	log.info("Bye")
}

update :: proc(dt: Seconds) {
	player_update(dt)

	queue_ui_update(dt)

	state.button_pressed = false
	state.prev_pointer = state.pointer
}

draw :: proc(ctx: ^Context) {
	defer free_all(context.temp_allocator)

	cairo.set_antialias(ctx, .NONE)

	// Fill background.
	set_source_color(ctx, WHITE)
	cairo.paint(ctx)

	// TEMPORARY: for now all text fonts will be the same.
	set_font(ctx, state.font_kapli, 16)

	queue_ui_draw(ctx)
}

_window_draw :: proc "c" (window: ^win.Window, cr: ^cairo.cairo_t, surface: ^cairo.surface_t) {
	context = make_default_context()

	ctx: Context
	ctx.cr = cr
	ctx.surface = surface
	ctx.screen = surface_rect(surface)
	ctx.container = ctx.screen

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
	switch button_state {
	case .Released:
		state.buttons -= {button}
		state.button_down = false
	case .Pressed:
		state.buttons += {button}
		state.button_down = true
		state.button_pressed = true
		state.press_pos = state.pointer
	}
}
_window_on_pointer_motion :: proc "c" (window: ^win.Window, x, y: f64) {
	state.pointer = {i32(x), i32(y)}
}
_window_on_pointer_scroll :: proc "c" (window: ^win.Window, x, y: f64, touchpad: bool) {
	context = make_default_context()

	scroll := f32(y)

	queue_on_scroll(scroll, touchpad)
}
