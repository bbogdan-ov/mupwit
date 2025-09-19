#ifndef TWEEN_H
#define TWEEN_H

#include <math.h>

// Thanks to easings.net
#define EASE_IN_OUT_SINE(X) (-(cos(PI * (X)) - 1.0) / 2.0)
#define EASE_OUT_CUBIC(X) (1 - pow(1 - (X), 3))
#define EASE_IN_OUT_CUBIC(X) ((X) < 0.5 ? 4.0 * (X) * (X) * (X) : 1.0 - pow(-2.0 * (X) + 2.0, 3.0) / 2.0)

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
