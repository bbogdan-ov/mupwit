#ifndef PROGRESS_BAR_H
#define PROGRESS_BAR_H

#include "./draw.h"
#include "../assets.h"
#include "../state.h"

#define PROGRESS_BAR_HEIGHT 4
#define PROGRESS_BAR_EXPAND 4

typedef enum ProgressBarEvent {
	PROGRESS_BAR_DRAGGING = 1,
	PROGRESS_BAR_STOPPED,
} ProgressBarEvent;

typedef struct ProgressBar {
	ProgressBarEvent events;
	float progress;
	Rect rect;
	Color color;
	bool draw_thumb;
} ProgressBar;

// Draw progress bar or range input if you like
// Returns bit mask of the current progress bar events
void progress_bar_draw(ProgressBar *bar, State *state, Assets *assets);

#endif
