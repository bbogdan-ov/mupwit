#include <raylib.h>

#include "./scrollable.h"
#include "../macros.h"

Scrollable scrollable_new() {
	return (Scrollable){0};
}

void scrollable_update(Scrollable *s) {
	// TODO: scroll only when mouse is over the scrollable thingy
	Vector2 wheel = GetMouseWheelMoveV();
	s->scroll -= wheel.y * 20;

	if (s->scroll > s->height)
		s->scroll = s->height;
	else if (s->scroll < 0)
		s->scroll = 0;
}

void scrollable_set_height(Scrollable *s, float height) {
	s->height = MAX(height, 0);
}
