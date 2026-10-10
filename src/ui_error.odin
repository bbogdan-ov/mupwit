//
// Screen for some horrible errors like failed connection to a MPD server.
//

package mupwit

import "core:fmt"

import "lib:ui"

@(private = "file")
self: struct {
	retry_button: ui.Button,
}

error_ui_update :: proc(state: ^State, dt: Seconds) {
	if state.error == nil do return

	if ui.button_update(&self.retry_button) {
		try_connect_again(state)
	}
}

error_ui_draw :: proc(state: ^State, ctx: ^ui.Context) {
	error, ok := state.error.?
	if !ok do return

	// TODO: add a link to MPD installation guide when i write it.

	G :: GAP / 2

	text :: proc(ctx: ^ui.Context, text: string, pos: Vec2, color: Color) -> i32 {
		ui.draw_text(ctx, text, pos, color, .Center)
		return ctx.font_height + G
	}

	black := state.theme.black
	gray := state.theme.gray
	gap := ctx.font_height + G

	pos := rect_size(ctx.box) / 2
	pos.y += ctx.font_height

	pos.y += text(ctx, "Failed to connect!", pos, black)
	pos.y += text(ctx, state.player.address, pos, black)
	pos.y += gap
	pos.y += text(ctx, fmt.tprintf("Error: %v", error), pos, gray)
	pos.y += gap

	{
		pos.y -= ctx.font_height

		glyphs := ui.text_glyphs(ctx, "Try again")
		defer ui.text_glyphs_delete(glyphs)

		rect := text_button_rect(ctx, glyphs, pos)
		rect.x -= rect.width / 2
		draw_text_button_impl(ctx, &self.retry_button, glyphs, rect, black)
	}
}

// ------------------------------
// Listeners.
// ------------------------------

error_ui_on_keyboard_key :: proc(state: ^State, ev: Key_Event) -> (propagate: bool) {
	if state.error == nil do return true

	#partial switch ev.key {
	case .Enter, .Space, .F5:
		try_connect_again(state)
		return false
	case:
		return true
	}
}
