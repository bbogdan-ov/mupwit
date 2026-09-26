package mupwit

import "core:math"
import "core:strings"
import "lib:ui"

@(private = "file")
self: struct {
	entry:  ui.Entry,
	tween:  ui.Tween(f32),
	offset: f32,
	active: bool,
}

command_ui_init :: proc() {
	ui.entry_init(&self.entry, context.allocator)
}

command_ui_destroy :: proc() {
	ui.entry_destroy(&self.entry)
}

command_ui_update :: proc(state: ^State, dt: Seconds) {
	ui.tween_update(&self.tween, dt)
}

_command_ui_execute :: proc(state: ^State) -> (ok: bool) {
	text := ui.entry_string(&self.entry)
	space := strings.index_byte(text, ' ')
	if space < 0 do space = len(text)
	name := text[:space]

	return command_execute_from_name(state, name)
}

command_ui_draw :: proc(state: ^State, ctx: ^ui.Context) {
	MAX_OFFSET :: -(FONT_SIZE + GAP * 2 + GAP)

	p := ui.tween_ease(&self.tween, self.offset, .Cubic_Out)
	offset := MAX_OFFSET * (1 - p)
	if offset <= MAX_OFFSET do return

	black := state.theme.black
	text_color := state.theme.background

	init_height := ctx.font_height + GAP * 2 + 1

	box := ui.pad(ctx.box.rect, GAP)
	box.y += i32(offset)
	box.height = 10 * (ctx.font_height + GAP)
	h := math.lerp(f32(init_height), f32(box.height), p)
	box.height = i32(h)

	ui.draw_box(ctx, box, black, filled = true)

	ui.begin_box(ctx, box)
	ui.begin_clip(ctx)

	// Draw command prompt.
	{
		ui.begin_box(ctx, ctx.box, GAP)
		ui.begin_crop_text(ctx, false)

		ui.entry_draw(
			ctx,
			&self.entry,
			rect = ctx.box,
			selection = state.theme.gray,
			color = text_color,
			prefix = ":",
		)
	}

	ui.begin_box(ctx, ui.pad_t(ctx.box, init_height + GAP), GAP)

	// Draw commands list.
	pos := rect_pos(ctx.box)
	for binding in state.commands.list {
		if binding.alias_to != nil do continue

		ui.draw_text(ctx, binding.name, pos, text_color)

		desc := COMMAND_DESCRIPTION[binding.command]
		if len(desc) > 0 {
			p := pos
			p.x = ctx.box.x + ctx.box.width / 3
			ui.draw_text(ctx, desc, p, state.theme.light_gray)
		}

		pos.y += ctx.font_height + GAP
	}
}

command_ui_set_active :: proc(active: bool) {
	ui.dirty_set(&self.active, active)

	if active {
		ui.entry_clear(&self.entry)
		ui.tween_play(&self.tween, self.offset, COMMAND_ANIM_DURATION)
		self.offset = 1
	} else {
		ui.tween_play(&self.tween, self.offset, COMMAND_ANIM_DURATION)
		self.offset = 0
	}
}

command_ui_on_keyboard_key :: proc(state: ^State, ev: Key_Event) -> (propagate: bool) {
	if !self.active do return true

	if ev.key == .Backspace && len(self.entry.sb.buf) == 0 {
		command_ui_set_active(false)
		return false
	}

	switch {
	case is_key(ev, .Esc), is_ctrl_key(ev, .C), is_ctrl_key(ev, .Left_Brace):
		command_ui_set_active(false)

	case:
		commited := ui.entry_on_keyboard_key(&self.entry, ev)
		if commited {
			_command_ui_execute(state) or_break
			command_ui_set_active(false)
		}
	}

	return false
}
