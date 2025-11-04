#ifndef DRAW_H
#define DRAW_H

#include <raylib.h>

#include "../theme.h"
#include "../assets.h"

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
	BOX_FILLED_NORMAL,
} Box;

typedef enum Line {
	LINE_CURLY = 0,
} Line;


void draw_texture_quad(Texture tex, Rect rect, Color tint);

Vec measure_text(Text *text);

void draw_text(Text text);
Vec draw_cropped_text(Text text, float max_width, Color background);

void draw_icon(Assets *assets, Icon icon, Vec pos, Color color);
void draw_box(Assets *assets, Box box, Rect rect, Color color);
void draw_line(Assets *assets, Line line, Vec pos, float width, Color color);

bool is_key_pressed(KeyboardKey key);
bool is_shift_down(void);

Vec get_mouse_pos(void);

Rect screen_rect(void);

Rect rect_shrink(Rect rect, float hor, float ver);

char *get_temp_buf(void);

#define TIME_BUF_LEN 12

// Unsafe and fast write text representation of the seconds into the buffer
// Buffer size must be >= `TIME_BUF_LEN` (12)
// Returns length of the written text
int format_time(char *buffer, unsigned secs, bool minus);

// Unsafe and fast write text representation of the number into the buffer
// Returns length of the written text
// Returns `-1` if number is too large
int fast_int_fmt(char *buffer, int num, int pad);
// Unsafe and fast write null-terminated string into the buffer
// Returns length of the written text
int fast_str_fmt(char *buffer, const char *s);

// Update and resize existing texture from the specified image and load a new
// one if doesn't exist
void update_texture_from_image(Texture *tex, Image image);

#endif
