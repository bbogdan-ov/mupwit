package mupwit

import "base:runtime"
import "core:fmt"
import "core:log"

import "lib:cairo"
import "lib:mpd"
import win "lib:my_window"

Seconds :: mpd.Seconds

State :: struct {
	player:            Player,

	// Assets.
	font_library:      win.Font_Library,
	font_kapli:        Font,
	image_icons_sheet: ^cairo.surface_t,
	image_icons:       [Icon]^cairo.surface_t,
}

state: State

main :: proc() {
	context.logger = make_logger()

	// player_connect()
	// player_destroy()
	// if true do return

	window := win.window_new(WINDOW_WIDTH, WINDOW_HEIGHT)
	assert(window != nil) // TODO: handle error.

	win.window_set_resizable(window, false)
	win.window_set_draw_callback(window, _window_draw)
	win.window_set_pointer_motion_callback(window, _window_on_pointer_motion)

	assets_load()

	player_connect()

	for win.window_should_run(window) {}

	log.info("Closing the window...")
	win.window_destroy(window)
	assets_destroy()

	player_destroy()

	log.info("Bye")
}

draw :: proc(ctx: ^Context) {
	defer free_all(context.temp_allocator)

	player := &state.player

	set_source_color(ctx, WHITE)
	cairo.paint(ctx)

	cairo.set_font_face(ctx, state.font_kapli)
	cairo.set_font_size(ctx, 16)

	set_source_color(ctx, BLACK)
	cairo.save(ctx)
	cairo.move_to(ctx, 8, 16)
	cairo.show_text(ctx, fmt.ctprint(player.playstate))
	cairo.restore(ctx)

	for song, i in player.queue {
		cairo.save(ctx)
		cairo.move_to(ctx, 8, f64(i) * 20 + 64)
		cairo.show_text(ctx, fmt.ctprintf("%v - %v", song.title, song.artist))
		cairo.restore(ctx)
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

_window_on_pointer_motion :: proc "c" (window: ^win.Window, x, y: f64) {}
