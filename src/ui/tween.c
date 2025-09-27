#include <raylib.h>

#include "./tween.h"
#include "../macros.h"

Tween tween_new(int duration_ms) {
	return (Tween){
		.duration_ms = duration_ms,
		.timer_ms = duration_ms,
		.delay_ms = 0,
	};
}

void tween_update(Tween *t) {
	if (tween_playing(t))
		t->timer_ms += (int)(GetFrameTime() * 1000);
}

void tween_play(Tween *t, int delay_ms) {
	t->timer_ms = 0;
	t->delay_ms = delay_ms;
}

bool tween_playing(Tween *t) {
	return t->timer_ms < t->duration_ms + t->delay_ms;
}
float tween_progress(Tween *t) {
	return CLAMP((float)(t->timer_ms - t->delay_ms) / (float)t->duration_ms, 0.0, 1.0);
}
