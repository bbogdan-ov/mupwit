package mupwit

import "base:runtime"
import "core:math/ease"
import "core:strings"

import "lib:ui"

Toast_Level :: enum {
	Info = 0,
	Warn,
	Error,
}

@(private = "file")
self: struct {
	tween:     ui.Tween(f32),
	reveal:    f32,
	text:      string,
	level:     Toast_Level,
	timer:     Seconds,
	allocator: runtime.Allocator, // Text allocator.
	revealing: bool,
	jumping:   bool,
}

toast_ui_destroy :: proc() {
	delete(self.text, self.allocator)
}

toast_ui_update :: proc(state: ^State, dt: Seconds) {
	ui.tween_update(&self.tween, dt)

	if self.timer > 0 {
		self.timer -= dt
		if self.timer <= 0 {
			_toast_set_reveal(false)
		}
	}
}

toast_ui_draw :: proc(state: ^State, ctx: ^ui.Context) {
	glyphs := ui.text_glyphs(ctx, self.text)
	defer ui.text_glyphs_delete(glyphs)

	ext := ui.measure_glyphs(ctx, glyphs)

	H_PAD :: GAP + GAP / 2
	V_PAD :: GAP
	MARGIN :: GAP

	easing: ease.Ease
	if self.jumping {
		easing = .Back_In
	} else if self.revealing {
		easing = .Cubic_Out
	} else {
		easing = .Sine_In
	}
	reveal := ui.tween_ease(&self.tween, self.reveal, easing)

	scale: f32 = 1
	if !self.jumping {
		if self.revealing {
			easing = .Exponential_Out
		} else {
			easing = .Cubic_In
		}
		scale = ui.tween_ease(&self.tween, self.reveal, easing)
	}

	view := ui.state.view

	rect: Rect
	rect.width = i32(ext.x_advance) + H_PAD * 2
	rect.width = min(rect.width, view.width - MARGIN * 2)
	rect.width = i32(f32(rect.width) * scale)
	rect.height = ctx.font_height + V_PAD * 2

	offset_y := rect.height + ui.SPEECH_BUBBLE_TAIL_SIZE + MARGIN

	rect.x = view.width - rect.width - MARGIN
	rect.y = view.height - offset_y
	rect.y -= status_ui_visible_height()
	rect.y += i32(f32(offset_y) * (1 - reveal))

	ui.begin_box(ctx, rect, {H_PAD, V_PAD})

	ui.draw_speech_bubble(ctx, rect, state.theme.gray)

	ui.guard_clip(ctx)
	ui.begin_crop_text(ctx, false)

	pos := rect_pos(rect) + {H_PAD, V_PAD}
	pos.y += ctx.font_height
	ui.draw_glyphs(ctx, glyphs, pos, state.theme.background)
}

toast_set :: proc(text: string, allocator := context.allocator, level := Toast_Level.Info) {
	if len(text) > 0 {
		delete(self.text, self.allocator)
		self.text = strings.clone(text, allocator)
		self.allocator = allocator
		self.level = level
		self.timer = TOAST_DURATION

		if self.reveal > 0.5 {
			self.reveal = 1.15
			self.jumping = true
			_toast_set_reveal(true, 0.15)
		} else {
			_toast_set_reveal(true)
		}
	} else {
		self.timer = 0
		_toast_set_reveal(false)
	}
}

_toast_set_reveal :: proc(reveal: bool, duration := TOAST_ANIM_DURATION) {
	ui.tween_play(&self.tween, self.reveal, duration)
	self.reveal = 1 if reveal else 0
	if !reveal do self.jumping = false
	self.revealing = reveal
}
