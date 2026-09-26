package ui

import "core:math"
import "core:math/ease"

_ :: ease
_ :: math

Tween :: struct($T: typeid) {
	from:            T,
	timer, duration: Seconds,
}

tween_play :: proc(t: ^Tween($T), from: T, duration: Seconds) {
	t.from = from
	t.timer = duration
	t.duration = duration
}

tween_update :: proc(t: ^Tween($T), dt: Seconds, set_dirty := true) -> (updated: bool) {
	if t.timer > 0 {
		t.timer -= dt
		if t.timer <= 0 do t.timer = 0
		dirty(set_dirty)
		return true
	}
	return false
}

tween_finish :: proc(t: ^Tween($T)) {
	t.timer = 0
}

tween_progress :: proc(t: ^Tween($T)) -> f32 {
	if t.duration <= 0 do return 1.0
	if t.timer <= 0 do return 1.0

	return 1.0 - f32(t.timer / t.duration)
}

// TODO: replace with para-poly function that accepts an easing function when
// this get fixed:
//     https://github.com/odin-lang/Odin/issues/5977
tween_ease_any :: proc(t: ^Tween($T), to: T, kind: ease.Ease) -> T where T != Color {
	p := tween_progress(t)
	if p <= 0.0 do return t.from
	if p >= 1.0 do return to
	return math.lerp(t.from, to, ease.ease(kind, p))
}

tween_ease_color :: proc(t: ^Tween(Color), to: Color, easing: ease.Ease) -> Color {
	p := tween_progress(t)
	if p <= 0.0 do return t.from
	if p >= 1.0 do return to
	return color_lerp(t.from, to, ease.ease(easing, p))
}

tween_ease :: proc {
	tween_ease_any,
	tween_ease_color,
}

time_ease :: proc "contextless" (time, duration: Seconds, easing: ease.Ease) -> f32 {
	if duration <= 0 do return 1
	p := 1 - clamp(time / duration, 0, 1)
	return ease.ease(easing, p)
}
