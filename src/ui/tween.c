#include <raylib.h>

#include "./tween.h"
#include "../macros.h"

Tween tween_new(unsigned duration_ms) {
	return (Tween){
		.duration_ms = duration_ms,
		.timer_ms = duration_ms,
	};
}

void tween_update(Tween *t) {
	if (tween_playing(t))
		t->timer_ms += (unsigned)(GetFrameTime() * 1000);
}

void tween_play(Tween *t) {
	t->timer_ms = 0;
}

bool tween_playing(Tween *t) {
	return t->timer_ms < t->duration_ms;
}
float tween_progress(Tween *t) {
	return MIN(MAX((float)t->timer_ms / (float)t->duration_ms, 0.0), 1.0);
}
