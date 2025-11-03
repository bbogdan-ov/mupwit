#ifndef SCROLLABLE_H
#define SCROLLABLE_H

#include "./timer.h"
#include "../state.h"

typedef struct Scrollable {
	int scroll;
	int prev_scroll;
	int target_scroll;
	int height;
	Timer tween;
} Scrollable;

Scrollable scrollable_new(void);

void scrollable_update(Scrollable *s);

void scrollable_scroll_by(Scrollable *s, int movement);
void scrollable_set_height(Scrollable *s, int height);

void scrollable_draw_thumb(Scrollable *s, State *state, Color color);

#endif
