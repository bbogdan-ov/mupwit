#include "./button.h"

bool draw_icon_button(Context ctx, Icon icon, Vec pos) {
	Rect rec = rect(pos.x, pos.y, ICON_BUTTON_SIZE, ICON_BUTTON_SIZE);
	bool is_hovering = CheckCollisionPointRec(get_mouse_pos(), rec);

	if (is_hovering)
		ctx.state->cursor = MOUSE_CURSOR_POINTING_HAND;
	if (is_hovering && IsMouseButtonDown(MOUSE_BUTTON_LEFT))
		pos.y += 1;

	pos.x += ICON_BUTTON_SIZE/2 - ICON_SIZE/2;
	pos.y += ICON_BUTTON_SIZE/2 - ICON_SIZE/2;
	draw_icon(ctx.assets, icon, pos, THEME_BLACK);

	return is_hovering && IsMouseButtonReleased(MOUSE_BUTTON_LEFT);
}

