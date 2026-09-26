package ui

import "core:strings"
import "core:text/edit"
import "core:unicode/utf8"

import win "lib:my_window"

Entry_Command :: edit.Command

// One-line editable text box.
Entry :: struct {
	sb:    strings.Builder,
	state: edit.State,
}

entry_init :: proc(e: ^Entry, allocator := context.allocator) {
	e.sb = strings.builder_make(allocator)
	edit.init(&e.state, allocator, allocator)
	edit.setup_once(&e.state, &e.sb)
}

entry_destroy :: proc(e: ^Entry) {
	strings.builder_destroy(&e.sb)
	edit.destroy(&e.state)
}

entry_update :: proc(e: ^Entry) {
	edit.update_time(&e.state)
}
entry_on_keyboard_key :: proc(e: ^Entry, ev: win.Key_Event) -> (commited: bool) {
	is_key :: win.is_key
	is_ctrl_key :: win.is_ctrl_key
	is_shift_key :: win.is_shift_key
	is_ctrl_shift_key :: win.is_ctrl_shift_key

	shift := win.Mods{.Shift}
	ctrl := win.Mods{.Ctrl}
	ctrl_shift := win.Mods{.Ctrl, .Shift}

	cmd := Entry_Command.None
	
	// odinfmt:disable
	switch {
	case ev.key == .Left:
		switch ev.mods {
		case nil:        cmd = .Left
		case ctrl:       cmd = .Word_Left
		case shift:      cmd = .Select_Left
		case ctrl_shift: cmd = .Select_Word_Left
		}
	case ev.key == .Right:
		switch ev.mods {
		case nil:        cmd = .Right
		case ctrl:       cmd = .Word_Right
		case shift:      cmd = .Select_Right
		case ctrl_shift: cmd = .Select_Word_Right
		}

	case is_key(ev, .Up), is_key(ev, .Home):
		cmd = .Start
	case is_key(ev, .Down), is_key(ev, .End), is_ctrl_key(ev, .E):
		cmd = .End

	case ev.key == .Backspace:
		switch ev.mods {
		case nil:  cmd = .Backspace
		case ctrl: cmd = .Delete_Word_Left
		}
	case ev.key == .Delete:
		switch ev.mods {
		case nil:  cmd = .Delete
		case ctrl: cmd = .Delete_Word_Right
		}
	case is_ctrl_key(ev, .U):
		entry_clear(e)

	case is_ctrl_key(ev, .Z):
		cmd = .Undo
	case is_ctrl_shift_key(ev, .Z), is_ctrl_key(ev, .Y):
		cmd = .Redo

	case is_ctrl_key(ev, .A):
		cmd = .Select_All

	case is_key(ev, .Enter), is_ctrl_key(ev, .J):
		commited = true

	case:
		if utf8.is_control(utf8.rune_at_pos(ev.text, 0)) do break
		entry_insert_text(e, ev.text)
	}
	// odinfmt:enable

	entry_perform(e, cmd)

	return commited
}

entry_perform :: proc(e: ^Entry, command: Entry_Command) {
	edit.perform_command(&e.state, command)
}
entry_insert_text :: proc(e: ^Entry, text: string) {
	edit.input_text(&e.state, text)
}
entry_clear :: proc(e: ^Entry) {
	edit.undo_check(&e.state)
	strings.builder_reset(&e.sb)
	e.state.selection = {}
}

entry_string :: proc(e: ^Entry) -> string {
	return strings.to_string(e.sb)
}

entry_draw :: proc(ctx: ^Context, e: ^Entry, background, text_color: Color) {
	glyphs := text_glyphs(ctx, entry_string(e))
	defer text_glyphs_delete(glyphs)

	ext := measure_glyphs(ctx, glyphs)

	pos := Vec2{10, 10}
	rect := Rect{pos.x, pos.y, i32(ext.x_advance), ctx.font_height}
	rect = pad(rect, -4)
	rect.height += 2

	draw_rect(ctx, rect, background)

	{
		c1 := e.state.selection[0]
		c2 := e.state.selection[1]
		low_ext := measure_glyphs(ctx, glyphs[:c1])
		high_ext := measure_glyphs(ctx, glyphs[:c2])
		low := i32(low_ext.x_advance)
		high := i32(high_ext.x_advance)

		if low > high {
			low, high = high, low
		}

		p := pos + {low - 1, 0}
		w := max(high - low, 1)
		draw_rect(ctx, {p.x, p.y, w, ctx.font_height + 2}, text_color)
	}

	draw_glyphs(ctx, glyphs, pos + {0, ctx.font_height}, text_color)
}
