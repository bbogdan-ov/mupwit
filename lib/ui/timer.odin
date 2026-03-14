package ui

import "core:math"

Timer :: struct #all_or_none {
	// How much seconds elapsed since timer start.
	elapsed:  u32,
	duration: u32,
}

timer_make :: proc "contextless" (duration: u32) -> Timer {
	return Timer{elapsed = duration, duration = duration}
}

timer_start :: proc "contextless" (timer: ^Timer, duration: u32 = 0) {
	if duration > 0 do timer.duration = duration
	timer.elapsed = 0
}
timer_update :: proc "contextless" (timer: ^Timer) {
	if !timer_finished(timer^) {
		timer.elapsed += window.delta
	}
}

timer_finished :: #force_inline proc "contextless" (timer: Timer) -> bool {
	return timer.elapsed >= timer.duration
}
timer_progress :: #force_inline proc "contextless" (timer: Timer) -> f32 {
	return math.clamp(f32(timer.elapsed) / f32(timer.duration), 0, 1)
}
// Interpolate from `start` to `end` using an easing function.
timer_lerp :: #force_inline proc "contextless" (
	timer: Timer,
	easing: proc "contextless" (x: f32) -> f32,
	start: f32,
	end: f32,
) -> f32 {
	return math.lerp(start, end, easing(timer_progress(timer)))
}

ease_out_sine :: proc "contextless" (x: f32) -> f32 {
	return math.sin((x * math.PI) / 2)
}
