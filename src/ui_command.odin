package mupwit

import "core:strings"

import "lib:ui"

@(private = "file")
self: struct {
	entry:        ui.Entry,
	offset_tween: ui.Animated(f32),
	dim_tween:    ui.Animated(f32),
}

command_ui_init :: proc() {
	ui.animated_set(&self.offset_tween, f32(COMMAND_HEIGHT))
	self.offset_tween.duration = COMMAND_ANIM_DURATION
	self.offset_tween.easing = .Cubic_Out

	self.dim_tween.duration = 0.1
	self.dim_tween.easing = .Sine_In_Out

	ui.entry_init(&self.entry, context.allocator)
}

command_ui_destroy :: proc() {
	ui.entry_destroy(&self.entry)
}

command_ui_update :: proc(state: ^State, dt: Seconds) {
	ui.animated_update(&self.offset_tween, dt)
	ui.animated_update(&self.dim_tween, dt)
}

_command_ui_execute :: proc(state: ^State) -> (ok: bool) {
	text := ui.entry_string(&self.entry)
	space := strings.index_byte(text, ' ')
	if space < 0 do space = len(text)
	name := text[:space]

	return command_execute_from_name(state, name)
}

command_ui_set_active :: proc(active: bool) {
	if self.entry.active == active do return

	if active {
		ui.play_to(&self.offset_tween, 0)
		ui.play_to(&self.dim_tween, 0)

		ui.entry_clear(&self.entry)
	} else {
		ui.play_to(&self.offset_tween, f32(COMMAND_HEIGHT))
	}

	self.entry.active = active
	ui.dirty(true)
}

command_ui_visible_height :: proc() -> i32 {
	return COMMAND_HEIGHT - i32(self.offset_tween.value)
}

command_ui_draw :: proc(state: ^State, ctx: ^ui.Context) {
	offset := i32(self.offset_tween.value)
	if offset >= COMMAND_HEIGHT do return

	box := ctx.box.rect
	box.y -= i32(self.offset_tween.value)
	box.height = ctx.font_height + COMMAND_PADDING.y * 2 + 4

	// Draw wavy background.
	{
		color := ui.color_lerp(state.theme.black, state.theme.gray, self.dim_tween.value)

		ui.draw_box_wavy(ctx, box, color)
	}

	ui.guard_box(ctx, box, COMMAND_PADDING)
	ui.guard_clip(ctx)
	ui.guard_crop_text(ctx, false)

	// Draw command prompt.
	style := ui.Entry_Style {
		text_color      = state.theme.background,
		selection_color = state.theme.gray,
		prefix          = ":",
	}
	ui.entry_draw(ctx, &self.entry, ctx.box, style)
}

// ------------------------------
// Listeners.
// ------------------------------

command_ui_on_keyboard_key :: proc(state: ^State, ev: Key_Event) -> (propagate: bool) {
	if !self.entry.active do return true

	is_empty := len(self.entry.sb.buf) == 0

	switch {
	case ev.key == .Backspace && is_empty:
		command_ui_set_active(false)

	case is_key_cancel(ev):
		command_ui_set_active(false)

	case is_key(ev, .Enter), is_ctrl_key(ev, .J):
		_command_ui_execute(state) or_break
		command_ui_set_active(false)

	case:
		ui.entry_on_keyboard_key(&self.entry, ev)
	}

	return false
}
