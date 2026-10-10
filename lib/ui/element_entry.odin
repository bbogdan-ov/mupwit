package ui

import "core:strings"
import "core:text/edit"
import "core:unicode/utf8"

import "lib:cairo"
import win "lib:my_window"

Entry_Command :: edit.Command

ENTRY_CHANGING_COMMANDS :: edit.Command_Set {
	.Undo,
	.Redo,
	.New_Line,
	.Cut,
	.Copy,
	.Paste,
	.Backspace,
	.Delete,
	.Delete_Word_Left,
	.Delete_Word_Right,
}

// One-line editable text box.
Entry :: struct {
	sb:     strings.Builder,
	state:  edit.State,
	active: bool,
}

Entry_Style :: struct {
	text_color:          Color,
	selection_color:     Color,
	placeholder_color:   Color,
	prefix, placeholder: string,
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

entry_set_active :: proc(e: ^Entry, active: bool) {
	dirty_set(&e.active, active)
}

entry_perform :: proc(e: ^Entry, command: Entry_Command) -> (changed: bool) {
	edit.perform_command(&e.state, command)
	return command in ENTRY_CHANGING_COMMANDS
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
entry_len :: proc(e: ^Entry) -> int {
	return len(e.sb.buf)
}

entry_glyphs :: proc(
	ctx: ^Context,
	e: ^Entry,
	prefix := "",
) -> (
	text: string,
	glyphs: []cairo.glyph_t,
) {
	text = entry_string(e)
	if len(prefix) > 0 {
		buf := make([]u8, len(prefix) + len(text), context.temp_allocator)
		copy(buf[:len(prefix)], transmute([]u8)prefix)
		copy(buf[len(prefix):], transmute([]u8)text)
		text = transmute(string)buf
	}

	return text, text_glyphs(ctx, text)
}

entry_draw :: proc(
	ctx: ^Context,
	e: ^Entry,
	rect: Rect,
	style: Entry_Style,
) -> (
	text_advance: Vec2,
) {
	text, glyphs := entry_glyphs(ctx, e, style.prefix)
	defer text_glyphs_delete(glyphs)
	return entry_draw_glyphs(ctx, e, text, glyphs, rect, style)
}

// TODO!: text should scroll when overflowing a box.
// TODO: implement selection using mouse at some point.
entry_draw_glyphs :: proc(
	ctx: ^Context,
	e: ^Entry,
	text: string,
	glyphs: []cairo.glyph_t,
	rect: Rect,
	style: Entry_Style,
) -> (
	text_advance: Vec2,
) {
	pos := rect_pos(rect)

	if e.active {
		head := e.state.selection[0] + len(style.prefix)
		tail := e.state.selection[1] + len(style.prefix)
		is_sel := head != tail

		number: int
		head_char, tail_char: int
		for char, i in text {
			size := utf8.rune_size(char)
			defer number += 1

			if i + size <= head do head_char = number + 1
			if i + size <= tail do tail_char = number + 1
		}

		tail_ext: cairo.text_extents_t
		head_ext := measure_glyphs(ctx, glyphs[:head_char], false)
		if head_char != tail_char {
			tail_ext = measure_glyphs(ctx, glyphs[:tail_char], false)
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
		draw_rect(ctx, cursor, style.selection_color if is_sel else style.text_color)
	}

	text_pos := pos + {0, ctx.font_height}
	ext := draw_glyphs(ctx, glyphs, text_pos, style.text_color)

	if len(entry_string(e)) == 0 && len(style.placeholder) > 0 {
		text_pos.x += i32(ext.x_advance)
		draw_text(ctx, style.placeholder, text_pos, style.placeholder_color)
	}

	return {i32(ext.x_advance), i32(ext.y_advance)}
}

// ------------------------------
// Listeners.
// ------------------------------

entry_on_keyboard_key :: proc(e: ^Entry, ev: win.Key_Event) -> (changed: bool) {
	if !e.active do return false

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
		changed = true
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

	case:
		if utf8.is_control(utf8.rune_at_pos(ev.text, 0)) do break
		entry_insert_text(e, ev.text)
		changed = true
	}
	// odinfmt:enable

	dirty(true)

	changed |= entry_perform(e, cmd)

	return changed
}
