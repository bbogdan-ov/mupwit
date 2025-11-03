#include <raylib.h>

#include "./timer.h"
#include "../macros.h"

Timer timer_new(unsigned duration_ms, bool looping) {
	return (Timer){
		.elapsed_ms = duration_ms,
		.duration_ms = duration_ms,
		.looping = looping,
	};
}

void timer_update(Timer *t) {
	if (!timer_playing(t)) return;

	t->elapsed_ms += (unsigned)(GetFrameTime() * 1000);
	if (t->looping) {
		t->elapsed_ms = 0;
	}
}

void timer_play(Timer *t) {
	t->elapsed_ms = 0;
}

bool timer_playing(const Timer *t) {
	return t->looping || t->elapsed_ms < t->duration_ms;
}
bool timer_finished(const Timer *t) {
	return !t->looping && t->elapsed_ms >= t->duration_ms;
}
float timer_progress(const Timer *t) {
	return MIN(MAX((float)t->elapsed_ms / (float)t->duration_ms, 0.0), 1.0);
}
