#include "./progress_bar.h"

ProgressBarEvent progress_bar_draw(State *state, float *progress, Rect rect, Color color) {
	rect.height = PROGRESS_BAR_HEIGHT;

	draw_box(state, BOX_NORMAL, rect, color);

	ProgressBarEvent action = 0;
	static bool is_dragging = false;
	bool is_hovering = CheckCollisionPointRec(
		get_mouse_pos(),
		rect_shrink(rect, 0, -PROGRESS_BAR_EXPAND)
	);

	if (is_hovering)
		state->cursor = MOUSE_CURSOR_POINTING_HAND;

	if (is_hovering && IsMouseButtonPressed(MOUSE_BUTTON_LEFT)) {
		is_dragging = true;
	}
	if (is_dragging) {
		action |= PROGRESS_BAR_DRAGGING;

		float offset_x = GetMouseX() - rect.x;
		*progress = offset_x / rect.width;
		if (*progress > 1.0) *progress = 1.0;
		else if (*progress < 0.0) *progress = 0.0;

		if (!IsMouseButtonDown(MOUSE_BUTTON_LEFT)) {
			action |= PROGRESS_BAR_STOPPED;
			is_dragging = false;
		}
	}

	// Draw progress bar fill
	Rect fill_rect = rect_shrink(rect, 1, 1);
	fill_rect.width = floor(fill_rect.width * *progress);
	DrawRectangleRec(fill_rect, color);

	// Draw progress bar thumb
	Vec thumb_pos = {
		fill_rect.x + fill_rect.width - ICON_SIZE/2,
		rect.y + rect.height/2 - ICON_SIZE/2
	};
	draw_icon(state, ICON_PROGRESS_THUMB, thumb_pos, color);

	return action;
}
