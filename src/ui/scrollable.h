#ifndef SCROLLABLE_H
#define SCROLLABLE_H

#include "./tween.h"

#define SCROLL_WHEEL_MOVEMENT 64

typedef struct Scrollable {
	int scroll;
	int prev_scroll;
	int target_scroll;
	int height;
	Tween tween;
} Scrollable;

Scrollable scrollable_new();

void scrollable_update(Scrollable *s);

void scrollable_scroll_by(Scrollable *s, int movement);
void scrollable_set_height(Scrollable *s, int height);

#endif
