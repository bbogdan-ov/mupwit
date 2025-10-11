#include "./button.h"

bool draw_icon_button(State *state, Icon icon, Vec pos) {
	Rect rec = rect(pos.x, pos.y, ICON_BUTTON_SIZE, ICON_BUTTON_SIZE);
	bool hover = CheckCollisionPointRec(get_mouse_pos(), rec);

	if (hover)
		state->cursor = MOUSE_CURSOR_POINTING_HAND;
	if (hover && IsMouseButtonDown(MOUSE_BUTTON_LEFT))
		pos.y += 1;

	pos.x += ICON_BUTTON_SIZE/2 - ICON_SIZE/2;
	pos.y += ICON_BUTTON_SIZE/2 - ICON_SIZE/2;
	draw_icon(state, icon, pos, THEME_BLACK);

	return hover && IsMouseButtonReleased(MOUSE_BUTTON_LEFT);
}

