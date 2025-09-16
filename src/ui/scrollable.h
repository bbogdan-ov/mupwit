#ifndef SCROLLABLE_H
#define SCROLLABLE_H

typedef struct Scrollable {
	float scroll;
	float velocity;
	float height;
} Scrollable;

Scrollable scrollable_new();

void scrollable_update(Scrollable *s);

void scrollable_set_height(Scrollable *s, float height);

float scrollable_get_scroll(Scrollable *s);

#endif
