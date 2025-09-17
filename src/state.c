#include <assert.h>
#include <math.h>

#include "./theme.h"
#include "./state.h"

#include "../build/assets.h"

#define FONT(NAME) (Font){ \
		.baseSize = NAME ## _BASE_SIZE, \
		.glyphCount = NAME ## _GLYPH_COUNT, \
		.glyphPadding = NAME ## _GLYPH_PADDING, \
		.texture = LoadTextureFromImage( \
			(Image){NAME ## _IMAGE_DATA, NAME ## _IMAGE_WIDTH, NAME ## _IMAGE_HEIGHT, 1, NAME ## _PIXEL_FORMAT} \
		), \
		.recs = NAME ## _RECTS, \
		.glyphs = NAME ## _GLYPHS, \
	}

#define TEXTURE(NAME) LoadTextureFromImage( \
	(Image){NAME ## _DATA, NAME ## _WIDTH,  NAME ## _HEIGHT, 1, NAME ## _PIXEL_FORMAT})

State state_new(void) {
	return (State){
		.normal_font = FONT(code9x7),
		.title_font = FONT(comicoro),

		.icons = TEXTURE(icons),
		.boxes = TEXTURE(boxes),

		.empty_artwork = TEXTURE(empty_artwork),
		.artwork_tween = tween_new(300),

		.background = THEME_BACKGROUND,
		.prev_background = THEME_BACKGROUND,
		.background_tween = tween_new(1000),
	};
}

void set_prev_artwork(State *s) {
	// FIXME: raylib won't allow me to update the texture size, so
	// i have to delete the previous texture and create a new one. Or does it?..
	if (s->prev_artwork.exists)
		UnloadTexture(s->prev_artwork.texture);

	if (!s->cur_artwork.exists || s->cur_artwork.texture.id == 0) {
		s->prev_artwork.exists = false;
		return;
	}

	s->prev_artwork = s->cur_artwork;
	s->prev_artwork.exists = true;
}

void state_update(State *s) {
	tween_update(&s->artwork_tween);
	tween_update(&s->background_tween);

	Color target_color = THEME_BACKGROUND;
	if (s->cur_artwork.exists) {
		target_color = s->cur_artwork.average;
		target_color = ColorContrast(target_color, 0.8);
		target_color = ColorBrightness(target_color, 0.6);
	}

	// FIXME: color animates at the startup, but we don't want that
	s->background = ColorLerp(
		s->prev_background,
		target_color,
		EASE_IN_OUT_SINE(tween_progress(&s->background_tween))
	);
}

void play_tweens(State *s) {
	s->prev_background = s->background;
	tween_play(&s->background_tween);
	tween_play(&s->artwork_tween);
}

void state_set_artwork(State *s, Image image, Color average) {
	set_prev_artwork(s);

	// Update current artwork texture
	s->cur_artwork.texture = LoadTextureFromImage(image);
	SetTextureFilter(s->cur_artwork.texture, TEXTURE_FILTER_BILINEAR);
	s->cur_artwork.average = average;
	s->cur_artwork.exists = true;

	play_tweens(s);
}
void state_clear_artwork(State *s) {
	s->cur_artwork.exists = false;
	play_tweens(s);
}

void state_next_page(State *s) {
	switch (s->page) {
		case PAGE_PLAYER: s->page = PAGE_QUEUE; break;
		case PAGE_QUEUE: s->page = PAGE_PLAYER; break;
	}
}
void state_prev_page(State *s) {
	switch (s->page) {
		case PAGE_PLAYER: s->page = PAGE_QUEUE; break;
		case PAGE_QUEUE: s->page = PAGE_PLAYER; break;
	}
}
