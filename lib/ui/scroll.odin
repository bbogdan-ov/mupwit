package ui

import "core:math"
Scroll :: struct #all_or_none {
	// Actual vertical offset of the scroll.
	// Used to smoothly interpolate `offset` to this value.
	_actual_offset: f32,
	_prev_offset:   f32,
	// Vertical offset of the scroll.
	offset:         f32,
	tween:          Timer,
}

scroll_create :: proc() -> Scroll {
	return Scroll {
		_actual_offset = 0,
		_prev_offset = 0,
		offset = 0,
		tween = timer_create(SCROLL_TWEEN_DURATION),
	}
}

scroll_update :: proc(scroll: ^Scroll, scroll_height: f32, container_height: f32) {
	if window.wheel.y != 0 {
		max_offset := math.max(scroll_height - container_height, 0)

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
