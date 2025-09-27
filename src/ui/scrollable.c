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
	Vector2 wheel = GetMouseWheelMoveV();

	scrollable_scroll_by(s, (int)wheel.y * -SCROLL_WHEEL_MOVEMENT);
	s->target_scroll = CLAMP(s->target_scroll, 0, s->height);

	tween_update(&s->tween);

	if (tween_playing(&s->tween)) {
		s->scroll = (int)Lerp(
			s->prev_scroll,
			s->target_scroll,
			EASE_OUT_CUBIC(tween_progress(&s->tween))
		);
	} else {
		s->scroll = (int)s->target_scroll;
	}
}

void scrollable_scroll_by(Scrollable *s, int movement) {
	if (movement == 0) return;

	s->prev_scroll = s->scroll;
	s->target_scroll += movement;
	tween_play(&s->tween, 0);
}
void scrollable_set_height(Scrollable *s, int height) {
	s->height = MAX(height, 0);
}
