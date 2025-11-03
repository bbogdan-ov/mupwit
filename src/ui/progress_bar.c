#include "./progress_bar.h"

void progress_bar_draw(ProgressBar *bar, State *state, Assets *assets) {
	Rect rect = {bar->rect.x, bar->rect.y, bar->rect.width, PROGRESS_BAR_HEIGHT};

	draw_box(assets, BOX_NORMAL, rect, bar->color);

	bool is_hovering = CheckCollisionPointRec(
		get_mouse_pos(),
		rect_shrink(rect, 0, -PROGRESS_BAR_EXPAND)
	);

	if (is_hovering)
		state->cursor = MOUSE_CURSOR_POINTING_HAND;

	if (bar->events & PROGRESS_BAR_STOPPED) {
		bar->events = 0;
	}

	if (is_hovering && IsMouseButtonPressed(MOUSE_BUTTON_LEFT)) {
		bar->events |= PROGRESS_BAR_DRAGGING;
	}
	if (bar->events & PROGRESS_BAR_DRAGGING) {
		float offset_x = GetMouseX() - rect.x;
		bar->progress = offset_x / rect.width;
		if (bar->progress > 1.0) bar->progress = 1.0;
		else if (bar->progress < 0.0) bar->progress = 0.0;

		if (!IsMouseButtonDown(MOUSE_BUTTON_LEFT)) {
			bar->events |= PROGRESS_BAR_STOPPED;
		}
	}

	// Draw progress bar fill
	Rect fill_rect = rect_shrink(rect, 0, 1);
	fill_rect.width = floor(fill_rect.width * bar->progress);
	DrawRectangleRec(fill_rect, bar->color);

	// Draw progress bar thumb
	if (bar->draw_thumb) {
		Vec thumb_pos = {
			fill_rect.x + fill_rect.width - ICON_SIZE/2,
			rect.y + rect.height/2 - ICON_SIZE/2
		};
		draw_icon(assets, ICON_PROGRESS_THUMB, thumb_pos, bar->color);
	}
}
