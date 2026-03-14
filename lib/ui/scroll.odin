package ui

import "core:math"
Scroll :: struct #all_or_none {
	// Actual vertical offset of the scroll.
	// Used to smoothly interpolate `offset` to this value.
	_actual_offset: f32,
	_prev_offset:   f32,
	// Vertical offset of the scroll.
	offset:         f32,
	// How long are the contents of the scrolling container.
	length:         f32,
	tween:          Timer,
}

scroll_create :: proc() -> Scroll {
	return Scroll {
		_actual_offset = 0,
		_prev_offset = 0,
		offset = 0,
		length = 0,
		tween = timer_create(SCROLL_TWEEN_DURATION),
	}
}

scroll_update :: proc(scroll: ^Scroll, length: f32, container_height: f32) {
	scroll.length = length

	if window.wheel.y != 0 {
		max_offset := math.max(length - container_height, 0)

		scroll._prev_offset = scroll.offset
		scroll._actual_offset -= window.wheel.y * SCROLL_SENSITIVITY
		scroll._actual_offset = math.clamp(scroll._actual_offset, 0, max_offset)

		when SCROLL_TWEEN_DURATION > 0 {
			timer_start(&scroll.tween)
		}
	}

	when SCROLL_TWEEN_DURATION > 0 {
		timer_update(&scroll.tween)
	}

	when SCROLL_TWEEN_DURATION > 0 {
		offset := timer_lerp(
			scroll.tween,
			ease_out_sine,
			scroll._prev_offset,
			scroll._actual_offset,
		)
		scroll.offset = math.floor(offset)
	} else {
		scroll.offset = math.floor(scroll._actual_offset)
	}
}

scroll_draw :: proc(scroll: Scroll, container: Rect, offset_x: f32, color: Color) {
	c := container

	height := max(32, math.floor(c.height * c.height / scroll.length))
	if height >= c.height do return

	x := c.x + c.width + offset_x
	y := math.floor(c.y + scroll.offset * (c.height - height) / (scroll.length - c.height))
	draw_rect({x, y, SCROLL_THICKNESS, height}, color)
}
