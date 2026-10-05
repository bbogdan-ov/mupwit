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
	return clamp(1.0 - f32(t.timer / t.duration), 0, 1)
}

// TODO: replace with para-poly function that accepts an easing function when
// this get fixed:
//     https://github.com/odin-lang/Odin/issues/5977
tween_ease_any :: proc(t: ^Tween($T), to: T, easing: ease.Ease) -> T where T != Color {
	p := tween_progress(t)
	return math.lerp(t.from, to, ease.ease(easing, p))
}

tween_ease_color :: proc(t: ^Tween(Color), to: Color, easing: ease.Ease) -> Color {
	p := tween_progress(t)
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

// Animated value.
Animated :: struct($T: typeid) {
	using tween: Tween(T),
	to, value:   T,
	easing:      ease.Ease,
}

animated_play :: proc(a: ^Animated($T), from, to: T) {
	a.from = from
	a.to = to
	a.timer = a.duration
}
animated_play_to :: proc(a: ^Animated($T), to: T) {
	a.from = a.value
	a.to = to
	a.timer = a.duration
}

animated_play_with :: proc(a: ^Animated($T), from, to: T, duration: Seconds, easing: ease.Ease) {
	tween_play(&a.tween, from, duration)
	a.to = to
	a.easing = easing
}
animated_play_to_with :: proc(a: ^Animated($T), to: T, duration: Seconds, easing: ease.Ease) {
	tween_play(&a.tween, a.value, duration)
	a.to = to
	a.easing = easing
}

animated_set :: proc(a: ^Animated($T), value: T) {
	a.value = value
	a.from = value
	a.to = value
	a.timer = 0
	a.duration = 0
}

animated_update :: proc(a: ^Animated($T), dt: Seconds) {
	if tween_update(&a.tween, dt) {
		a.value = tween_ease(&a.tween, a.to, a.easing)
	}
}

play :: proc {
	tween_play,
	animated_play,
}

play_to :: proc {
	animated_play_to,
}
