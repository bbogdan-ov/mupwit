#include <raylib.h>
#include <math.h>

#include "./scrollable.h"
#include "../macros.h"

Scrollable scrollable_new() {
	return (Scrollable){0};
}

void scrollable_update(Scrollable *s) {
	// TODO: scroll only when mouse is over the scrollable thingy
	Vector2 wheel = GetMouseWheelMoveV();

	s->velocity -= wheel.y * 14;
	s->scroll += s->velocity;
	s->velocity *= 0.6;

	if (s->scroll > s->height)
		s->scroll = s->height;
	else if (s->scroll < 0)
		s->scroll = 0;
}

void scrollable_set_height(Scrollable *s, float height) {
	s->height = MAX(height, 0);
}

float scrollable_get_scroll(Scrollable *s) {
	return floor(s->scroll);
}
