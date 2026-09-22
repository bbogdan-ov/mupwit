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

tween_update :: proc(t: ^Tween($T), dt: Seconds) {
	if t.timer > 0 {
		t.timer -= dt
	} else {
		t.timer = 0
	}
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
tween_ease :: proc(t: ^Tween($T), to: T, kind: ease.Ease) -> T {
	p := tween_progress(t)
	return math.lerp(t.from, to, ease.ease(kind, p))
}
