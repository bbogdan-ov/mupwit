#ifndef PROGRESS_BAR_H
#define PROGRESS_BAR_H

#include "./draw.h"

#define PROGRESS_BAR_HEIGHT 4
#define PROGRESS_BAR_EXPAND 4

typedef enum ProgressBarEvent {
	PROGRESS_BAR_DRAGGING = 1,
	PROGRESS_BAR_STOPPED,
} ProgressBarEvent;

// Draw progress bar or range input if you like
// Returns bit mask of the current progress bar events
ProgressBarEvent progress_bar_draw(State *state, float *progress, Rect rect, Color color);

#endif
