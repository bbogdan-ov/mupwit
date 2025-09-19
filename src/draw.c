#include <raylib.h>

#include "./draw.h"
#include "./state.h"

Rect rect(float x, float y, float width, float height) {
	return (Rect){x, y, width, height};
}
Vec vec(float x, float y) {
	return (Vec){x, y};
}

void draw_texture_quad(Texture tex, Rect rect, Color tint) {
	DrawTexturePro(
		tex,
		(Rect){0, 0, tex.width, tex.height},
		rect,
		(Vec){0},
		0,
		tint
	);
}

Vec measure_text(Text *text) {
	return MeasureTextEx(text->font, text->text, text->size, 0);
}

void draw_text(Text text) {
	DrawTextEx(text.font, text.text, text.pos, text.size, 0, text.color);
}
Vec draw_cropped_text(Text text, float max_width, Color background) {
	draw_text(text);

	Vec bounds = measure_text(&text);
	if (bounds.x < max_width) return bounds;

	// Add gradient at the end of the song title if it exceeded the container
	DrawRectangleGradientH(
		text.pos.x + max_width - text.size * 2,
		text.pos.y,
		text.size * 2,
		text.size,
		ColorAlpha(background, 0.0),
		background
	);

	return bounds;
}

void draw_icon(State *state, Icon icon, Vec pos, Color color) {
	Rect source = rect(icon * ICON_SIZE, 0, ICON_SIZE, ICON_SIZE);
	Rect dest = rect(pos.x, pos.y, ICON_SIZE, ICON_SIZE);

	DrawTexturePro(state->icons, source, dest, (Vec){0}, 0, color);
}

void draw_box(State *state, Box box, Rect rect, Color color) {
	NPatchInfo npatch = (NPatchInfo){
		.source = {box * 18, 0, 18, 18},
		.left   = 6,
		.top    = 6,
		.right  = 6,
		.bottom = 6,
		.layout = NPATCH_NINE_PATCH,
	};

	rect = rect_shrink(rect, -3, -3);
	DrawTextureNPatch(state->boxes, npatch, rect, (Vec){0}, 0, color);
}

bool is_key_pressed(KeyboardKey key) {
	return IsKeyPressed(key) || IsKeyPressedRepeat(key);
}
bool is_shift_down() {
	return IsKeyDown(KEY_LEFT_SHIFT) || IsKeyDown(KEY_RIGHT_SHIFT);
}

Rect screen_rect() {
	return (Rect){0, 0, GetScreenWidth(), GetScreenHeight()};
}

Rect rect_shrink(Rect rect, float hor, float ver) {
	return (Rect){
		.x = rect.x + hor,
		.y = rect.y + ver,
		.width = rect.width - hor * 2,
		.height = rect.height - ver * 2,
	};
}

const char *format_time(unsigned secs) {
	if (secs > 60 * 60) {
		return TextFormat("%02d:%02d:%02d", (int)(secs / 60 / 60), (int)(secs / 60) % 60, secs % 60);
	} else if (secs > 60) {
		return TextFormat("%02d:%02d", (int)(secs / 60), secs % 60);
	} else {
		return TextFormat("00:%02d", secs);
	}
}

const char *format_elapsed_time(unsigned elapsed, unsigned duration) {
	return TextFormat("%s / %s", format_time(elapsed), format_time(duration));
}
