package ui

import "core:math"
import "core:math/ease"

Scroll :: struct #all_or_none {
	// Actual vertical offset of the scroll.
	// Used to smoothly interpolate `offset` from `_prev_offset` to `_actual_offset`.
	_actual_offset: f32,
	_prev_offset:   f32,
	// Vertical offset of the scrolling container's content.
	offset:         f32,
	// How long is the content of the scrolling container.
	length:         f32,
	tween:          Timer,
}

scroll_make :: proc "contextless" () -> Scroll {
	return Scroll {
		_actual_offset = 0,
		_prev_offset = 0,
		offset = 0,
		length = 0,
		tween = timer_make(SCROLL_TWEEN_DURATION),
	}
}

scroll_update :: proc "contextless" (scroll: ^Scroll, length: f32, container_height: f32) {
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

		offset := timer_lerp(
			scroll.tween,
			ease.sine_out,
			scroll._prev_offset,
			scroll._actual_offset,
		)
		scroll.offset = math.floor(offset)
	} else {
		scroll.offset = math.floor(scroll._actual_offset)
	}
}

scroll_draw :: proc "contextless" (scroll: Scroll, container: Rect, offset_x: f32, color: Color) {
	c := container

	height := max(32, math.floor(c.height * c.height / scroll.length))
	if height >= c.height do return

	x := c.x + c.width + offset_x
	y := math.floor(c.y + scroll.offset * (c.height - height) / (scroll.length - c.height))
	draw_rect({x, y, SCROLL_THICKNESS, height}, color)
}
