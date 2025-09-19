#ifndef TWEEN_H
#define TWEEN_H

#include <math.h>

// Thanks to easings.net
#define EASE_IN_OUT_SINE(x) (-(cos(PI * (x)) - 1.0) / 2.0)
#define EASE_OUT_CUBIC(x) (1 - pow(1 - (x), 3))
#define EASE_IN_OUT_CUBIC(x) ((x) < 0.5 ? 4.0 * (x) * (x) * (x) : 1.0 - pow(-2.0 * (x) + 2.0, 3.0) / 2.0)
#define EASE_IN_OUT_QUAD(x) (x < 0.5 ? 2 * x * x : 1 - pow(-2 * x + 2, 2) / 2)

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
