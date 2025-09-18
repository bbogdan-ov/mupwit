#ifndef SCROLLABLE_H
#define SCROLLABLE_H

#include "./tween.h"

#define SCROLL_WHEEL_MOVEMENT 64

typedef struct Scrollable {
	float scroll;
	float prev_scroll;
	float target_scroll;
	float height;
	Tween tween;
} Scrollable;

Scrollable scrollable_new();

void scrollable_update(Scrollable *s);

void scrollable_scroll_by(Scrollable *s, float movement);
void scrollable_set_height(Scrollable *s, float height);

#endif
