#include <assert.h>
#include <math.h>

#include "./theme.h"
#include "./state.h"
#include "./macros.h"

#include <raymath.h>

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

Color calc_foreground(Color bg) {
	int lum = ((int)bg.r + (int)bg.g + (int)bg.b) / 3;
	if (lum > 210)
		return ColorContrast(bg, -0.1);
	else
		return ColorContrast(bg, 0.2);
}

State state_new(void) {
	return (State){
		.normal_font = FONT(code9x7),
		.title_font = FONT(comicoro),

		.icons = TEXTURE(icons),
		.boxes = TEXTURE(boxes),

		.empty_artwork = TEXTURE(empty_artwork),

		.foreground = calc_foreground(THEME_BACKGROUND),
		.background = THEME_BACKGROUND,
		.prev_background = THEME_BACKGROUND,
		.background_tween = tween_new(1000),

		.page_tween = tween_new(200),
		.page_transition = 1.0,
	};
}

void state_update(State *s) {
	tween_update(&s->background_tween);
	tween_update(&s->page_tween);

	Color target_color = THEME_BACKGROUND;
	if (s->cur_artwork.exists) {
		target_color = s->cur_artwork.average;
		target_color = ColorContrast(target_color, 0.8);
		target_color = ColorBrightness(target_color, 0.6);
	}

	if (tween_playing(&s->background_tween)) {
		float progress = tween_progress(&s->background_tween);
		s->background = ColorLerp(
			s->prev_background,
			target_color,
			EASE_IN_OUT_SINE(progress)
		);
		s->foreground = calc_foreground(s->background);
	} else {
		// Leave as it is
	}

	if (tween_playing(&s->page_tween))
		s->page_transition = Lerp(
			s->prev_page_transition,
			1.0,
			EASE_IN_OUT_SINE(tween_progress(&s->page_tween))
		);
	else
		s->page_transition = 1.0;
}

void start_background_tween(State *s) {
	s->prev_background = s->background;
	tween_play(&s->background_tween);
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

void state_set_artwork(State *s, Image image, Color average) {
	set_prev_artwork(s);

	// Update current artwork texture
	s->cur_artwork.texture = LoadTextureFromImage(image);
	SetTextureFilter(s->cur_artwork.texture, TEXTURE_FILTER_BILINEAR);
	s->cur_artwork.average = average;
	s->cur_artwork.exists = true;

	start_background_tween(s);
}
void state_clear_artwork(State *s) {
	s->cur_artwork.exists = false;
	start_background_tween(s);
}

void set_page(State *s, Page page) {
	s->prev_page = s->page;
	s->page = page;

	s->prev_page_transition = 1.0 - s->page_transition;
	tween_play(&s->page_tween);
}

void state_next_page(State *s) {
	switch (s->page) {
		case PAGE_PLAYER: set_page(s, PAGE_QUEUE); break;
		case PAGE_QUEUE: set_page(s, PAGE_PLAYER); break;
	}
}
void state_prev_page(State *s) {
	switch (s->page) {
		case PAGE_PLAYER: set_page(s, PAGE_QUEUE); break;
		case PAGE_QUEUE: set_page(s, PAGE_PLAYER); break;
	}
}

float state_artwork_alpha(State *s) {
	return MIN(tween_progress(&s->background_tween) * 8.0, 1.0);
}
