package ui

import "core:math"

Scroll :: struct {
	container:         Container, // Container from previous draw frame.
	offset:            f32,
	from, to:          f32,
	velocity:          f32,
	timer:             Seconds,
	max_scroll:        f32,
	is_hovering:       bool,
	is_hovering_thumb: bool,
}

List_Params :: struct {
	item_count:  int,
	item_height: i32,
}

scroll_update :: proc(s: ^Scroll, dt: Seconds) {
	_scroll_update_offset(s, dt)
	_scroll_update_pointer_drag(s)
}

_scroll_update_offset :: proc(s: ^Scroll, dt: Seconds) {
	if s.timer > 0 {
		s.timer -= dt

		progress := 1.0 - f32(s.timer / SCROLL_ANIM_DURATION)
		s.offset = math.lerp(s.from, s.to, SCROLL_ANIM_EASE(progress))
	} else {
		s.timer = 0
	}

	s.offset += s.velocity

	if s.offset >= s.max_scroll {
		s.offset = s.max_scroll
		s.velocity = 0
	}
	if s.offset <= 0 {
		s.offset = 0
		s.velocity = 0
	}

	d := SCROLL_VELOCITY_DRAG * f32(dt)
	if s.velocity - d > 0 {
		s.velocity -= d
	} else if s.velocity + d < 0 {
		s.velocity += d
	} else {
		s.velocity = 0
	}
}

_scroll_update_pointer_drag :: proc(s: ^Scroll) {
	id := Element_ID(s)
	is_dragging := state.dragging == id

	cont := s.container

	switch {
	case is_dragging && is_mouse_down(.Left):
		length := scroll_content_length(s)
		factor := f32(cont.height) / f32(length)
		delta := f32(state.pointer.y - state.press_pos.y) / factor
		scroll_set(s, state.drag_scroll_offset + delta)

	case is_dragging:
		state.dragging = nil

	case s.is_hovering && is_mouse_pressed(.Left) && state.dragging == nil:
		state.dragging = id
		if s.is_hovering_thumb {
			state.drag_scroll_offset = s.offset
		} else {
			pos := state.pointer.y - s.container.y
			length := scroll_content_length(s)
			offset := length * pos / cont.height - cont.height / 2

			state.drag_scroll_offset = f32(offset)
		}
	}
}

scroll_on_scroll :: proc(s: ^Scroll, scroll: f32, touchpad: bool) {
	if touchpad {
		s.velocity = scroll * SCROLL_TOUCH_MULPLIER
	} else if !is_almost_zero(scroll) {
		if s.timer <= 0 {
			s.to = s.offset
		}

		s.from = s.offset
		s.to += scroll * SCROLL_WHEEL_MULPLIER
		s.to = clamp(s.to, 0, s.max_scroll)

		s.velocity = 0
		s.timer = SCROLL_ANIM_DURATION
	}
}

scroll_set :: proc(s: ^Scroll, offset: f32) {
	s.offset = clamp(offset, 0, s.max_scroll)
	s.timer = 0
	s.velocity = 0
}

scroll_draw :: proc(ctx: ^Context, s: ^Scroll, length: i32, color: Color) {
	cont := ctx.container

	length := max(length, 1)
	s.max_scroll = f32(length - cont.height)
	s.container = cont

	progress := s.offset / s.max_scroll

	thumb: Rect
	thumb.width = cont.padding.x
	thumb.height = max(cont.height * cont.height / length, 32)
	thumb.x = cont.x + cont.width
	thumb.y = cont.y + i32(f32(cont.height - thumb.height) * progress)
	if thumb.height >= cont.height do return

	s.is_hovering_thumb = overlap(state.pointer, thumb)

	click := cont
	click.width = cont.padding.x
	click.x = cont.x + cont.width
	s.is_hovering = overlap(state.pointer, click)

	{
		rect := thumb
		rect.width = SCROLL_THUMB_THICKNESS
		rect.x += thumb.width / 2 - rect.width / 2
		draw_rect(ctx, rect, color)
	}
}

// Returns the range of items within the current scrollable container that are
// visible on the screen.
// NOTE: all items must have the same height.
scroll_visible_items_range :: proc(
	ctx: ^Context,
	s: ^Scroll,
	list: List_Params,
) -> (
	from, to: int,
) {
	off := i32(s.offset) - ctx.container.y

	from = int(max(off, 0) / list.item_height)
	to = int(max(off + ctx.screen.height + list.item_height, 0) / list.item_height)
	to = min(to, list.item_count)
	return
}

// Returns index of an item within the current scrollable container that is
// being hovered by the mouse pointer.
// Returns -1 if nothing is being hovered.
scroll_hovering_item_index :: proc(
	ctx: ^Context,
	s: ^Scroll,
	list: List_Params,
) -> (
	index: int,
	ok: bool,
) {
	p := state.pointer
	p.y += i32(s.offset)
	rect := ctx.container
	rect.height += i32(s.offset)
	if !overlap(p, rect) do return -1, false

	index = int((p.y - ctx.container.y) / list.item_height)
	if !within(index, 0, list.item_count) do return index, false

	return index, true
}

scroll_content_length :: proc(s: ^Scroll) -> i32 {
	return i32(s.max_scroll) + s.container.height
}
