#ifndef TIMER_H
#define TIMER_H

#include <math.h>

// Thanks to easings.net
#define EASE_IN_OUT_SINE(x) (-(cos(PI * (x)) - 1.0) / 2.0)
#define EASE_OUT_CUBIC(x) (1 - pow(1 - (x), 3))
#define EASE_IN_OUT_CUBIC(x) ((x) < 0.5 ? 4.0 * (x) * (x) * (x) : 1.0 - pow(-2.0 * (x) + 2.0, 3.0) / 2.0)
#define EASE_IN_OUT_QUAD(x) (x < 0.5 ? 2 * x * x : 1 - pow(-2 * x + 2, 2) / 2)

typedef struct Timer {
	unsigned elapsed_ms;
	unsigned duration_ms;
	bool looping;
} Timer;

Timer timer_new(unsigned duration_ms, bool looping);

void timer_update(Timer *t);

void timer_play(Timer *t);

bool timer_playing(const Timer *t);
bool timer_finished(const Timer *t);
float timer_progress(const Timer *t);

#endif
