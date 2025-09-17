#ifndef TWEEN_H
#define TWEEN_H

#include <math.h>

#define EASE_IN_OUT_SINE(X) (-(cos(PI * X) - 1.0) / 2.0)

typedef struct Tween {
	unsigned duration_ms;
	unsigned timer_ms;
} Tween;

Tween tween_new(unsigned duration_ms);

void tween_update(Tween *t);

void tween_play(Tween *t);

bool tween_playing(Tween *t);
float tween_progress(Tween *t);

#endif
