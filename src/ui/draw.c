#include <raylib.h>
#include <string.h>

#include "./draw.h"
#include "../macros.h"

#include <GLES3/gl3.h>
#include <rlgl.h>

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

void draw_icon(Assets *assets, Icon icon, Vec pos, Color color) {
	Rect src = {icon * ICON_SIZE, 0, ICON_SIZE, ICON_SIZE};
	Rect dest = {pos.x, pos.y, ICON_SIZE, ICON_SIZE};

	DrawTexturePro(assets->icons, src, dest, (Vec){0}, 0, color);
}

void draw_box(Assets *assets, Box box, Rect rect, Color color) {
	NPatchInfo npatch = (NPatchInfo){
		.source = {box * 18, 0, 18, 18},
		.left   = 6,
		.top    = 6,
		.right  = 6,
		.bottom = 6,
		.layout = NPATCH_NINE_PATCH,
	};

	rect = rect_shrink(rect, -3, -3);
	DrawTextureNPatch(assets->boxes, npatch, rect, (Vec){0}, 0, color);
}

void draw_line(Assets *assets, Line line, Vec pos, float width, Color color) {
	Rect src = {0.0, line * LINE_SIZE, width, LINE_SIZE};
	Rect dest = {pos.x, pos.y, width, LINE_SIZE};
	DrawTexturePro(assets->lines, src, dest, (Vec){0}, 0.0, color);
}

bool is_key_pressed(KeyboardKey key) {
	return IsKeyPressed(key) || IsKeyPressedRepeat(key);
}
bool is_shift_down(void) {
	return IsKeyDown(KEY_LEFT_SHIFT) || IsKeyDown(KEY_RIGHT_SHIFT);
}

Vec get_mouse_pos(void) {
	if (!IsWindowFocused()) return (Vec){-999, -999};
	return GetMousePosition();
}

Rect screen_rect(void) {
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

char *get_temp_buf(void) {
#define MAX_BUFFERS 4
#define BUFFER_CAP 256

	static int index = 0;
	static char buffers[MAX_BUFFERS][BUFFER_CAP];

	char *buf = buffers[index];
	index = (index + 1) % MAX_BUFFERS;
	return buf;
}

int format_time(char *buffer, unsigned secs, bool minus) {
	int len = 0;

	if (minus) buffer[len++] = '-';

	if (secs > 60 * 60) {
		len += fast_int_fmt(buffer + len, secs / 60 / 60, 2); // hours
		buffer[len++] = ':';
		len += fast_int_fmt(buffer + len, secs / 60 % 60, 2); // mins
		buffer[len++] = ':';
		len += fast_int_fmt(buffer + len, secs % 60, 2); // secs
	} else if (secs > 60) {
		len += fast_int_fmt(buffer + len, secs / 60, 2); // mins
		buffer[len++] = ':';
		len += fast_int_fmt(buffer + len, secs % 60, 2); // secs
	} else {
		len += fast_str_fmt(buffer + len, "00:");
		len += fast_int_fmt(buffer + len, secs, 2); // secs
	}

	buffer[TIME_BUF_LEN - 1] = 0;
	return len;
}

int fast_int_fmt(char *buffer, int num, int pad) {
#define ASCII(X) (48 + (X)) // Retrieve ASCII code of the number X
#define OFFSET MAX(pad - len, 0)

	memset(buffer, ASCII(0), pad);

	int len;
	if (num <= 9) {
		len = 1;
		buffer[OFFSET + 0] = ASCII(num);
	} else if (num <= 99) {
		len = 2;
		buffer[OFFSET + 0] = ASCII(num / 10);
		buffer[OFFSET + 1] = ASCII(num % 10);
	} else if (num <= 999) {
		len = 3;
		buffer[OFFSET + 0] = ASCII(num / 100);
		buffer[OFFSET + 1] = ASCII(num / 10 % 10);
		buffer[OFFSET + 2] = ASCII(num % 10);
	} else if (num <= 9999) {
		len = 4;
		buffer[OFFSET + 0] = ASCII(num / 1000);
		buffer[OFFSET + 1] = ASCII(num / 100 % 10);
		buffer[OFFSET + 2] = ASCII(num / 10 % 10);
		buffer[OFFSET + 3] = ASCII(num % 10);
	} else if (num <= 99999) {
		len = 5;
		buffer[OFFSET + 0] = ASCII(num / 10000);
		buffer[OFFSET + 1] = ASCII(num / 1000 % 10);
		buffer[OFFSET + 2] = ASCII(num / 100 % 10);
		buffer[OFFSET + 3] = ASCII(num / 10 % 10);
		buffer[OFFSET + 4] = ASCII(num % 10);
	} else {
		return -1;
	}

	len = MAX(len, pad);
	buffer[len] = 0;
	return len;
}

int fast_str_fmt(char *buffer, const char *s) {
	int len = strlen(s);
	memcpy(buffer, s, len);
	buffer[len] = 0;
	return len;
}

void update_texture_from_image(Texture *tex, Image image) {
	assert(image.data != NULL);

	if (tex->id <= 0) {
		*tex = LoadTextureFromImage(image);
		SetTextureFilter(*tex, TEXTURE_FILTER_BILINEAR);
		return;
	}

	tex->width = image.width;
	tex->height = image.height;
	tex->format = image.format;

	// Dirty raw OPENGL hack to change texture and resize pixel data
	// because raylib doesn't have such feature out of the box

	unsigned int glInternalFormat, glFormat, glType;
	rlGetGlTextureFormats(tex->format, &glInternalFormat, &glFormat, &glType);

	glBindTexture(GL_TEXTURE_2D, tex->id);
	if ((glInternalFormat != 0) && (tex->format < PIXELFORMAT_COMPRESSED_DXT1_RGB)) {
		glTexImage2D(
			GL_TEXTURE_2D,
			0,
			glInternalFormat,
			tex->width,
			tex->height,
			0,
			glFormat,
			glType,
			image.data
		);
	} else {
		TraceLog(
			LOG_WARNING,
			"TEXTURE: [ID %i] Failed to update for current texture format (%i)",
			tex->id,
			tex->format
		);
	}
}

