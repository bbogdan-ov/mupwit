package mupwit

import "core:log"
import "core:math"
import "core:mem"
import "core:time"
import "lib:mpd"

import "lib:cairo"
import win "lib:my_window"
import "lib:ui"

Screen :: enum {
	Player = 0,
	Queue,
}

State :: struct {
	window:       ^win.Window,
	player:       Player,
	screen:       Screen,
	prev_screen:  Screen,
	screen_tween: ui.Tween(f32),

	// Assets.
	font_kapli:   ui.Font,
	icons:        ui.Sprites(Icon),
}

@(private = "file")
state: State

main :: proc() {
	context.logger = make_logger()

	track := make_tracking_allocator(context.allocator)
	context.allocator = mem.tracking_allocator(&track)
	defer tracking_allocator_report_and_destroy(&track)

	state.window = win.new(WINDOW_WIDTH, WINDOW_HEIGHT)
	assert(state.window != nil) // TODO: handle error.

	win.set_resizable(state.window, false)
	win.set_frame_callback(state.window, _window_on_frame)
	win.set_draw_callback(state.window, _window_draw)
	win.set_pointer_button_callback(state.window, _window_on_pointer_button)
	win.set_pointer_motion_callback(state.window, _window_on_pointer_motion)
	win.set_pointer_scroll_callback(state.window, _window_on_pointer_scroll)
	win.set_pointer_enter_callback(state.window, _window_on_pointer_enter)
	win.set_keyboard_key_callback(state.window, _window_on_keyboard_key)

	ui.init()
	assets_load(&state)

	player_init(&state.player)
	player_connect(&state.player)

	queue_ui_init()

	for win.should_run(state.window) {}

	log.info("Closing the window...")
	win.destroy(state.window)
	assets_destroy(&state)
	ui.destroy()

	player_destroy(&state.player)

	log.info("Bye")
}

update :: proc(dt: Seconds) {
	ui.tween_update(&state.screen_tween, dt)

	player_update(&state.player, dt)

	status_ui_update(&state, dt)
	queue_ui_update(&state, dt)
	player_ui_update(&state, dt)

	win.set_cursor(state.window, ui.state.cursor)
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

	player_ui_draw(&state, ctx)
	queue_ui_draw(&state, ctx)
	status_ui_draw(&state, ctx)

	@(static) time: f32 = 0
	time += 1
	y := i32(math.sin(time / 5.0) * 10)
	ui.draw_rect(ctx, {10, 20 + y, 16, 16}, RED)
}

set_screen :: proc(state: ^State, screen: Screen) {
	state.prev_screen = state.screen
	state.screen = screen
	ui.tween_play(&state.screen_tween, 0.9, SCREEN_ANIM_DURATION)
}

screen_y_offset :: proc(state: ^State) -> i32 {
	p := 1 - ui.tween_ease(&state.screen_tween, 1, .Cubic_Out)
	return i32(128 * p)
}

// ------------------------------
// Listeners.
// ------------------------------

on_keyboard_key :: proc(key: win.Key, key_state: win.Key_State, mods: win.Mods) {
	if key_state != .Pressed do return

	shift := .Shift in mods

	switch {
	case key == .Tab:
		v := int(state.screen)
		v += -1 if shift else +1
		set_screen(&state, Screen(ui.wrap(v, len(Screen))))
	}

	player_ui_on_keyboard_key(&state, key, mods)
}

on_pointer_scroll :: proc(scroll: f32, touchpad: bool) {
	queue_ui_on_scroll(&state, scroll, touchpad)
}

// These functions are called by the `Player` struct whenever something happens.

on_cur_song_updated :: proc() {
	player_ui_on_cur_song_updated(&state)
}
on_queue_updated :: proc() {
	queue_ui_on_received_queue(&state)
}
on_song_reordered :: proc(from, to: mpd.Song_Index) {
	queue_ui_on_song_reordered(from, to)
}

// These functions are listeners for window events.

_window_draw :: proc "c" (window: ^win.Window, cr: ^cairo.cairo_t, surface: ^cairo.surface_t) {
	context = make_default_context()

	ui.state.view = ui.surface_rect(surface)

	ctx: ui.Context
	ctx.cr = cr
	ctx.surface = surface
	ctx.box.rect = ui.state.view

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
	on_pointer_scroll(scroll, touchpad)
}
_window_on_pointer_enter :: proc "c" (window: ^win.Window, leave: bool) {
	if leave && ui.state.mouse_released_buttons == nil {
		ui.state.pointer = {-999, -999}
	}
}

_window_on_keyboard_key :: proc "c" (
	window: ^win.Window,
	key: win.Key,
	key_state: win.Key_State,
	mods: win.Mods,
) {
	context = make_default_context()
	on_keyboard_key(key, key_state, mods)
}
