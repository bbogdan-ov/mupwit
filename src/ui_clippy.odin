package mupwit

import "base:runtime"
import "core:math"
import "core:strings"

import "lib:ui"

Toast :: struct {
	tween:      ui.Animated(f32),
	jump_timer: Seconds,
}

@(private = "file")
self: struct {
	clippy_tween:  ui.Animated(f32),

	// Search toast.
	search_toast:  Toast,
	search:        ui.Entry,
	search_timer:  Seconds,
	search_screen: Maybe(Screen),
	search_rect:   Rect,

	// Message toast.
	msg_toast:     Toast,
	msg_text:      string,
	msg_allocator: runtime.Allocator,
	msg_timer:     Seconds,
}

clippy_ui_init :: proc() {
	ui.entry_init(&self.search, context.allocator)
}

clippy_ui_destroy :: proc() {
	delete(self.msg_text, self.msg_allocator)
	ui.entry_destroy(&self.search)
}

clippy_ui_update :: proc(state: ^State, dt: Seconds) {
	if self.msg_timer > 0 {
		self.msg_timer -= dt
		if self.msg_timer <= 0 {
			_toast_set_reveal(&self.msg_toast, false)
		}
	}

	if self.search_timer > 0 {
		self.search_timer -= dt
		if self.search_timer <= 0 {
			search := ui.entry_string(&self.search)
			search = strings.trim_space(search)
			push_event(state, Event_Search{search})
		}
	}

	if _toast_is_active(&self.search_toast) && ui.is_hovering(self.search_rect) {
		ui.set_cursor(.Pointer)

		if ui.is_clicked(.Left) {
			if self.search.active {
				_clippy_ui_search_commit()
			} else {
				_clippy_ui_search_focus()
			}
		}
	}

	ui.animated_update(&self.clippy_tween, dt)
	if self.clippy_tween.easing == .Linear {
		// NOTE: this is a crutch for setting less amplitude for "back out"
		// easing function.
		back_out :: proc "contextless" (p: $T) -> T {
			f := 1 - p
			return 1 - (f * f * f - f * math.sin(f * math.PI) * 0.4)
		}
		self.clippy_tween.value = back_out(self.clippy_tween.value)
	}

	ui.entry_update(&self.search)

	_toast_update(&self.msg_toast, dt)
	_toast_update(&self.search_toast, dt)
}

clippy_ui_set_message :: proc(text: string, allocator := context.allocator) {
	if len(text) > 0 {
		delete(self.msg_text, self.msg_allocator)
		self.msg_text = strings.clone(text, allocator)
		self.msg_allocator = allocator

		_toast_set_reveal(&self.msg_toast, true)
		self.msg_timer = TOAST_DURATION
	} else {
		_toast_set_reveal(&self.msg_toast, false)
		self.msg_timer = 0
	}
}

clippy_ui_allow_search :: proc(screen: Screen, initial_search: string) {
	self.search_screen = screen

	if len(initial_search) > 0 {
		ui.entry_clear(&self.search)
		ui.entry_insert_text(&self.search, initial_search)
		_clippy_ui_search_reveal(true)
	} else {
		_clippy_ui_search_reveal(false)
	}
}

_clippy_ui_search_focus :: proc() {
	if !_toast_is_active(&self.search_toast) {
		ui.entry_clear(&self.search)
	} else {
		ui.entry_perform(&self.search, .Select_All)
	}

	ui.entry_set_active(&self.search, true)
	_clippy_ui_search_reveal(true)
}

_clippy_ui_search_cancel :: proc(state: ^State) {
	if !(_toast_is_active(&self.search_toast) || self.search.active) {
		return
	}

	_clippy_ui_search_reveal(false)

	push_event(state, Event_Search{""})
	self.search_timer = 0
}

_clippy_ui_search_commit :: proc() {
	if ui.entry_len(&self.search) > 0 {
		ui.entry_set_active(&self.search, false)
	} else {
		_clippy_ui_search_reveal(false)
	}
}

_clippy_ui_search_reveal :: proc(reveal: bool) {
	_toast_set_reveal(&self.search_toast, reveal)
	if reveal {
		ui.animated_play_to_with(&self.clippy_tween, 1, 0.3, .Linear)
	} else {
		ui.animated_play_to_with(&self.clippy_tween, 0, 0.2, .Cubic_In)
		ui.entry_set_active(&self.search, false)
	}
}

clippy_ui_visible_height :: proc() -> i32 {
	off := TOAST_HEIGHT * self.search_toast.tween.value
	return i32(off)
}

clippy_ui_draw :: proc(state: ^State, ctx: ^ui.Context) {
	view := ui.state.view

	{
		off := status_ui_visible_height()

		pos := Vec2{view.width, view.height}
		pos -= IMAGE_CLIPPY_SIZE
		pos.x -= 2
		pos.y += -off + 16

		bottom := f32(view.height - off)
		y := math.lerp(bottom, f32(pos.y), self.clippy_tween.value)
		pos.y = i32(y)
		ui.draw_surface_tinted(ctx, state.image_clippy_outline, pos, state.theme.background)
		ui.draw_surface_tinted(ctx, state.image_clippy, pos, state.theme.black)
	}

	pos := Vec2{view.width, view.height}

	{
		pos := pos
		pos.y -= i32(TOAST_HEIGHT * self.search_toast.tween.value)
		_toast_draw(state, ctx, &self.msg_toast, self.msg_text, pos)
	}

	{
		pos := pos
		pos.x -= IMAGE_CLIPPY_SIZE.x
		_clippy_ui_draw_search_toast(state, ctx, pos)
	}
}

// TODO: add "next occurrence" and "previous occurrence" buttons when searching
// in a .Simple or .Reorderable list.
_clippy_ui_draw_search_toast :: proc(state: ^State, ctx: ^ui.Context, pos: Vec2) {
	view := ui.state.view

	style := ui.Entry_Style {
		text_color        = state.theme.background,
		selection_color   = state.theme.gray,
		placeholder_color = state.theme.light_gray,
		prefix            = "🔎 ",
		placeholder       = "…",
	}

	text, glyphs := ui.entry_glyphs(ctx, &self.search, prefix = style.prefix)
	defer ui.text_glyphs_delete(glyphs)

	ext := ui.measure_glyphs(ctx, glyphs, true)
	text_width := i32(ext.x_advance)
	text_width = max(text_width, view.width / 2)

	rect := _toast_draw_bubble(ctx, &self.search_toast, pos, text_width, state.theme.black)
	self.search_rect = rect

	ui.guard_box(ctx, rect, TOAST_PADDING)
	ui.guard_clip(ctx)
	ui.guard_crop_text(ctx, false)

	ui.entry_draw_glyphs(ctx, &self.search, text, glyphs, ctx.box, style)
}

// ------------------------------
// Listeners.
// ------------------------------

clippy_ui_on_keyboard_key :: proc(state: ^State, ev: Key_Event) -> (propagate: bool) {
	if self.search_screen == nil {
		return true
	}

	if is_key_cancel(ev) && (_toast_is_active(&self.search_toast) || self.search.active) {
		_clippy_ui_search_cancel(state)
		return false
	}

	switch {
	case !self.search.active:
		if is_key(ev, .Slash) || is_ctrl_key(ev, .F) || is_key(ev, .F3) {
			_clippy_ui_search_focus()
			return false
		}
		return true

	case ev.key == .Enter:
		_clippy_ui_search_commit()

	case:
		changed := ui.entry_on_keyboard_key(&self.search, ev)
		if changed {
			self.search_timer = SEARCH_DEBOUNCE
		}
	}

	return false
}

clippy_ui_on_screen_updated :: proc(state: ^State) {
	if state.screen != self.search_screen {
		_clippy_ui_search_reveal(false)
		self.search_screen = nil
		self.search_timer = 0
	}
}

// ------------------------------
// Toast.
// ------------------------------

_toast_update :: proc(toast: ^Toast, dt: Seconds) {
	ui.animated_update(&toast.tween, dt)
	if toast.jump_timer > 0 {
		toast.jump_timer -= dt
		ui.dirty(true)
		if toast.jump_timer <= 0 {
			toast.jump_timer = 0
		}
	}
}

_toast_set_reveal :: proc(toast: ^Toast, reveal: bool) {
	if reveal && _toast_is_active(toast) {
		toast.jump_timer = TOAST_ANIM_DURATION
	}

	toast.tween.duration = TOAST_ANIM_DURATION
	if reveal {
		toast.tween.easing = .Cubic_Out
	} else {
		toast.tween.easing = .Cubic_In
	}

	to: f32 = 1 if reveal else 0
	ui.play_to(&toast.tween, to)
}

_toast_is_active :: proc(toast: ^Toast) -> bool {
	return toast.tween.value > 0
}

_toast_draw :: proc(
	state: ^State,
	ctx: ^ui.Context,
	toast: ^Toast,
	text: string,
	bottom_right: Vec2,
) {
	if !_toast_is_active(toast) do return

	glyphs := ui.text_glyphs(ctx, text)
	defer ui.text_glyphs_delete(glyphs)

	ext := ui.measure_glyphs(ctx, glyphs, true)
	text_width := i32(ext.x_advance)

	rect := _toast_draw_bubble(ctx, toast, bottom_right, text_width, state.theme.gray)

	ui.guard_box(ctx, rect, TOAST_PADDING)
	ui.guard_clip(ctx)
	ui.guard_crop_text(ctx, false)

	text_pos := rect_pos(ctx.box)
	text_pos.y += ctx.font_height
	ui.draw_glyphs(ctx, glyphs, text_pos, state.theme.background)
}

_toast_draw_bubble :: proc(
	ctx: ^ui.Context,
	toast: ^Toast,
	bottom_right: Vec2,
	text_width: i32,
	color: Color,
) -> Rect {
	view := ui.state.view

	scale := math.lerp(f32(0.5), 1.0, toast.tween.value)

	rect: Rect
	rect.x = bottom_right.x
	rect.y = bottom_right.y - ui.SPEECH_BUBBLE_TAIL_SIZE
	rect.x -= TOAST_MARGIN
	rect.y -= TOAST_MARGIN
	rect.width = text_width + TOAST_PADDING.x * 2
	rect.width = min(rect.width, view.width - TOAST_MARGIN - (view.width - rect.x))
	rect.width = i32(f32(rect.width) * scale)
	rect.height = ctx.font_height + TOAST_PADDING.y * 2
	rect.x -= rect.width
	rect.y -= rect.height

	off := math.sin(toast.jump_timer / TOAST_ANIM_DURATION * math.PI)
	rect.y -= i32(off * 6)

	{
		y := math.lerp(f32(view.height), f32(rect.y), toast.tween.value)
		rect.y = i32(y) - status_ui_visible_height()
	}

	ui.draw_speech_bubble(ctx, rect, color)

	return rect
}
