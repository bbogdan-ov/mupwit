#ifndef DRAW_H
#define DRAW_H

#include <raylib.h>

#include "../theme.h"
#include "../state.h"

#define ICON_SIZE 16
#define LINE_SIZE 16

typedef struct Rectangle Rect;
typedef struct Vector2 Vec;

Rect rect(float x, float y, float width, float height);
Vec vec(float x, float y);

typedef struct Text {
	const char *text;
	Font font;
	int size;
	Vec pos;
	Color color;
} Text;

typedef enum Icon {
	ICON_PROGRESS_THUMB = 0,
	ICON_PLAY,
	ICON_PAUSE,
	ICON_PREV,
	ICON_NEXT,
	ICON_SMALL_ARROW,
	ICON_DISK,
} Icon;

typedef enum Box {
	BOX_NORMAL = 0,
	BOX_ROUNDED,
	BOX_3D,
	BOX_FILLED_ROUNDED,
} Box;

typedef enum Line {
	LINE_CURLY = 0,
} Line;


void draw_texture_quad(Texture tex, Rect rect, Color tint);

Vec measure_text(Text *text);

void draw_text(Text text);
Vec draw_cropped_text(Text text, float max_width, Color background);

void draw_icon(State *state, Icon icon, Vec pos, Color color);
void draw_box(State *state, Box box, Rect rect, Color color);
void draw_line(State *state, Line line, Vec pos, float width, Color color);

bool is_key_pressed(KeyboardKey key);
bool is_shift_down(void);

Vec get_mouse_pos(void);

Rect screen_rect(void);

Rect rect_shrink(Rect rect, float hor, float ver);

const char *format_time(unsigned secs, bool minus);

#endif
