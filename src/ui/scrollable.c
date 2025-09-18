#include <raylib.h>
#include <math.h>

#include "./scrollable.h"
#include "../macros.h"

#include <raymath.h>

Scrollable scrollable_new() {
	return (Scrollable){
		.tween = tween_new(300),
	};
}

void scrollable_update(Scrollable *s) {
	// TODO: scroll only when mouse is over the scrollable thingy
	Vector2 wheel = GetMouseWheelMoveV();

	scrollable_scroll_by(s, -wheel.y * SCROLL_WHEEL_MOVEMENT);
	s->target_scroll = CLAMP(s->target_scroll, 0, s->height);

	tween_update(&s->tween);

	if (tween_playing(&s->tween)) {
		s->scroll = floor(Lerp(
			s->prev_scroll,
			s->target_scroll,
			EASE_OUT_CUBIC(tween_progress(&s->tween))
		));
	} else {
		s->scroll = floor(s->target_scroll);
	}
}

void scrollable_scroll_by(Scrollable *s, float movement) {
	if (movement == 0.0) return;

	s->prev_scroll = s->scroll;
	s->target_scroll += movement;
	tween_play(&s->tween);
}
void scrollable_set_height(Scrollable *s, float height) {
	s->height = MAX(height, 0);
}
