package ui

import "core:strings"
import "core:text/edit"
import "core:unicode/utf8"

import "lib:cairo"
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
		case ctrl: cmd = .Delete_Word_Left
		case:      cmd = .Backspace
		}
	case ev.key == .Delete:
		switch ev.mods {
		case ctrl: cmd = .Delete_Word_Right
		case:      cmd = .Delete
		}
	case is_ctrl_key(ev, .U):
		entry_clear(e)
	case is_ctrl_key(ev, .W):
		cmd = .Delete_Word_Left
	case is_ctrl_key(ev, .H):
		cmd = .Backspace

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
	dirty(true)

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

// TODO!: handle text overflowing box. Should scroll to the right.
// TODO: implement selection using mouse at some point.
entry_draw :: proc(
	ctx: ^Context,
	e: ^Entry,
	rect: Rect,
	selection, color: Color,
	prefix := "",
) -> (
	text_advance: Vec2,
) {
	text := entry_string(e)
	if len(prefix) > 0 {
		cap := len(text) + len(prefix)
		sb := strings.builder_make_len_cap(0, cap, context.temp_allocator)
		strings.write_string(&sb, prefix)
		strings.write_string(&sb, text)
		text = strings.to_string(sb)
	}

	glyphs := text_glyphs(ctx, text)
	defer text_glyphs_delete(glyphs)

	pos := rect_pos(rect)

	{
		head := e.state.selection[0] + len(prefix)
		tail := e.state.selection[1] + len(prefix)
		is_sel := head != tail

		tail_ext: cairo.text_extents_t
		head_ext := measure_glyphs(ctx, glyphs[:head])
		if head != tail {
			tail_ext = measure_glyphs(ctx, glyphs[:tail])
		} else {
			tail_ext = head_ext
		}

		low, high := range_sort(i32(head_ext.x_advance), i32(tail_ext.x_advance))

		cursor := Rect {
			x      = pos.x + low - 1,
			y      = pos.y - 1,
			width  = max(high - low, 1),
			height = ctx.font_height + 4,
		}
		draw_rect(ctx, cursor, selection if is_sel else color)
	}

	text_pos := pos + {0, ctx.font_height}
	ext := draw_glyphs(ctx, glyphs, text_pos, color)
	return {i32(ext.x_advance), i32(ext.y_advance)}
}
