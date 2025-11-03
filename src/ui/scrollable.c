#include <raylib.h>
#include <math.h>

#include "./scrollable.h"
#include "../macros.h"

#include <raymath.h>

#define SCROLL_WHEEL_MOVEMENT 64
#define THUMB_THICKNESS 2

Scrollable scrollable_new(void) {
	return (Scrollable){
		.tween = timer_new(300, false),
	};
}

void scrollable_update(Scrollable *s) {
	Vector2 wheel = GetMouseWheelMoveV();

	scrollable_scroll_by(s, (int)wheel.y * -SCROLL_WHEEL_MOVEMENT);
	s->target_scroll = CLAMP(s->target_scroll, 0, s->height);

	timer_update(&s->tween);

	if (timer_playing(&s->tween)) {
		s->scroll = (int)Lerp(
			s->prev_scroll,
			s->target_scroll,
			EASE_OUT_CUBIC(timer_progress(&s->tween))
		);
	} else {
		s->scroll = (int)s->target_scroll;
	}
}

void scrollable_scroll_by(Scrollable *s, int movement) {
	if (movement == 0) return;

	s->prev_scroll = s->scroll;
	s->target_scroll += movement;
	timer_play(&s->tween);
}
void scrollable_set_height(Scrollable *s, int height) {
	s->height = MAX(height, 0);
}

void scrollable_draw_thumb(Scrollable *s, State *state, Color color) {
	// TODO: implement dragging the thumb to scroll
	int cont_height = (int)state->container.height;
	int scroll_height = cont_height + (int)s->height;
	int thumb_height = MAX(cont_height * cont_height / scroll_height, 32);
	if (thumb_height < cont_height)
		DrawRectangle(
			state->container.x + state->container.width + 3,
			state->container.y + s->scroll * (cont_height - thumb_height) / (int)s->height,
			THUMB_THICKNESS,
			thumb_height,
			color
		);
}
