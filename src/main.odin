package mupwit

import "core:log"
import "core:mem"
import "core:time"
import "lib:mpd"

import "lib:cairo"
import win "lib:my_window"
import "lib:ui"

Screen :: enum {
	Player = 0,
	Queue,
	Albums,
}

Theme :: struct {
	background:         Color,
	gray:               Color,
	light_gray:         Color,
	black:              Color,
	_target_background: Color,
	tween:              ui.Tween(Color),
}

State :: struct {
	window:       ^win.Window,
	player:       Player,
	screen:       Screen,
	prev_screen:  Screen,
	screen_tween: ui.Tween(f32),
	theme:        Theme,

	// Assets.
	font_kapli:   ui.Font,
	icons:        ui.Sprites(Icon),
}

@(private = "file")
state: State

main :: proc() {
	context.logger = make_logger()

	defer log.info("Bye")

	track := make_tracking_allocator(context.allocator)
	context.allocator = mem.tracking_allocator(&track)
	defer tracking_allocator_report_and_destroy(&track)

	state.window = win.new(WINDOW_WIDTH, WINDOW_HEIGHT)
	assert(state.window != nil) // TODO: handle error.

	win.set_title(state.window, "mupwit", "mupwit")
	win.set_resizable(state.window, false)
	win.set_frame_callback(state.window, _window_on_frame)
	win.set_draw_callback(state.window, _window_draw)
	win.set_pointer_button_callback(state.window, _window_on_pointer_button)
	win.set_pointer_motion_callback(state.window, _window_on_pointer_motion)
	win.set_pointer_scroll_callback(state.window, _window_on_pointer_scroll)
	win.set_pointer_enter_callback(state.window, _window_on_pointer_enter)
	win.set_keyboard_key_callback(state.window, _window_on_keyboard_key)

	state.theme.background = DEFAULT_BACKGROUND
	state.theme._target_background = DEFAULT_BACKGROUND
	state.theme.black = BOBO_BLACK
	_adapt_theme_colors_to_bg()

	ui.init()
	assets_load(&state)

	player_init(&state.player)
	player_connect(&state.player)
	defer player_destroy(&state.player)

	status_ui_init()
	queue_ui_init()
	defer queue_ui_destroy()
	albums_ui_init()
	defer albums_ui_destroy()

	for win.should_run(state.window) {}

	log.info("Closing the window...")
	win.destroy(state.window)
	assets_destroy(&state)
	ui.destroy()
}

update :: proc(dt: Seconds) {
	ui.tween_update(&state.screen_tween, dt)

	update_theme(dt)

	player_update(&state.player, dt)

	status_ui_update(&state, dt)
	queue_ui_update(&state, dt)
	player_ui_update(&state, dt)
	albums_ui_update(&state, dt)

	win.set_cursor(state.window, ui.state.cursor)
	ui.update(dt)
}

update_theme :: proc(dt: Seconds) {
	progress := ui.tween_progress(&state.theme.tween)
	if progress >= 1 do return

	ui.tween_update(&state.theme.tween, dt)

	bg: Color
	{
		to := state.theme._target_background
		bg = ui.tween_ease(&state.theme.tween, to, .Sine_In_Out)
		state.theme.background = bg
	}

	_adapt_theme_colors_to_bg()
}

_adapt_theme_colors_to_bg :: proc() {
	bg := state.theme.background

	hue, sat, light, _ := ui.color_to_hsl(bg)
	sat *= 0.5
	light *= 0.4
	state.theme.gray = ui.color_from_hsl(hue, sat, light)

	hue, sat, light, _ = ui.color_to_hsl(bg)
	sat *= 0.9
	light *= 0.9
	state.theme.light_gray = ui.color_from_hsl(hue, sat, light)
}

draw :: proc(ctx: ^ui.Context) {
	defer free_all(context.temp_allocator)

	cairo.set_antialias(ctx, .NONE)

	// Fill background.
	ui.set_source_color(ctx, state.theme.background)
	cairo.paint(ctx)

	// TEMPORARY: for now all text fonts will be the same.
	ui.set_font(ctx, state.font_kapli, FONT_SIZE)

	player_ui_draw(&state, ctx)
	queue_ui_draw(&state, ctx)
	albums_ui_draw(&state, ctx)
	status_ui_draw(&state, ctx)
}

set_screen :: proc(state: ^State, screen: Screen) {
	state.prev_screen = state.screen
	state.screen = screen
	ui.tween_play(&state.screen_tween, 0, SCREEN_ANIM_DURATION)
	on_screen_updated()
}

screen_x_offset :: proc(state: ^State, screen: Screen) -> i32 {
	p := ui.tween_ease(&state.screen_tween, 1, .Cubic_In_Out)
	vw := f32(ui.state.view.width)

	first := Screen(0)
	last := Screen(len(Screen) - 1)
	cur := state.screen
	prev := state.prev_screen

	dir: i32 = 1
	if cur == first && prev == last {
		dir = 1
	} else if cur == last && prev == first {
		dir = -1
	} else if cur < prev {
		dir = -1
	}

	if cur == screen {
		return i32(vw * (1 - p)) * dir
	} else if prev == screen {
		return -i32(vw * p) * dir
	} else {
		return 0
	}
}

screen_is_visible :: proc(state: ^State, screen: Screen) -> bool {
	if state.screen == screen do return true
	return state.prev_screen == screen && state.screen_tween.timer > 0
}

set_background :: proc(state: ^State, color: Color) {
	ui.tween_play(&state.theme.tween, state.theme.background, THEME_ANIM_DURATION)
	state.theme._target_background = color
}
set_background_from_cover :: proc(state: ^State, cover: ^Cover) {
	if cover.color.a > 0 {
		set_background(state, cover.color)
	} else {
		set_background(state, BOBO_WHITE)
	}
}

// ------------------------------
// Listeners.
// ------------------------------

on_keyboard_key :: proc(key: win.Key, key_state: win.Key_State, mods: win.Mods) {
	if key_state != .Pressed do return

	player := &state.player
	shift := .Shift in mods

	switch {
	case key == .Esc, key == .Q:
		win.set_should_close(state.window, true)

	case key == .Tab:
		diff := -1 if shift else +1
		screen := enum_rotate_variant(state.screen, diff)
		set_screen(&state, screen)

	case key == .Space:
		player_toggle_play(player)
	case key == .Dot && shift:
		player_next(player)
	case key == .Comma && shift:
		player_previous(player)
	}

	player_ui_on_keyboard_key(&state, key, mods)
}

// TODO: would be cool to add touchpad gestures.
on_pointer_scroll :: proc(scroll: f32, touchpad: bool) {
	queue_ui_on_scroll(&state, scroll, touchpad)
	albums_ui_on_scroll(&state, scroll, touchpad)
}

// TODO: may be i should refactor listeners that listen to value changes to bit set of "events"?

on_screen_updated :: proc() {
	queue_ui_on_screen_updated(&state)
}

// These functions are called by the `Player` struct whenever something happens.

on_cur_song_updated :: proc(prev_index: Maybe(mpd.Song_Index)) {
	player_ui_on_cur_song_updated(&state)
	queue_ui_on_cur_song_updated(&state, prev_index)
}
on_queue_updated :: proc() {
	queue_ui_on_received_queue(&state)
}
on_albums_updated :: proc() {
	albums_ui_on_albums_updated(&state)
}
on_song_reordered :: proc(from, to: mpd.Song_Index) {
	queue_ui_on_song_reordered(from, to)
}
on_song_removed :: proc(index: mpd.Song_Index) {
	queue_ui_on_song_removed(index)
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
