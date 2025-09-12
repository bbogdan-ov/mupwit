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
	// Load textures
	Texture empty_artwork = TEXTURE(empty_artwork);
	SetTextureFilter(empty_artwork, TEXTURE_FILTER_BILINEAR);

	return (State){
		.normal_font = FONT(code9x7),
		.title_font = FONT(comicoro),

		.icons = TEXTURE(icons),
		.boxes = TEXTURE(boxes),

		.empty_artwork = empty_artwork,

		.background = THEME_BACKGROUND,
		.prev_background = THEME_BACKGROUND,
		.transition_progress = 1.0,
	};
}

void set_prev_artwork(State *s) {
	// FIXME: raylib won't allow me to update the texture size, so
	// i have to delete the previous texture and create a new one
	if (s->prev_artwork.exists)
		UnloadTexture(s->prev_artwork.texture);

	if (!s->cur_artwork.exists || s->cur_artwork.texture.id == 0) {
		s->prev_artwork.exists = false;
		return;
	}

	s->prev_artwork = s->cur_artwork;
	s->prev_artwork.exists = true;
}

float ease_in_out_sine(float x) {
	return -(cos(PI * x) - 1.0) / 2.0;
}

void state_update(State *s) {
	if (s->transition_timer_ms > 0) {
		s->transition_timer_ms -= (int)(GetFrameTime() * 1000);
	}

	Color target_color = THEME_BACKGROUND;
	if (s->cur_artwork.exists) {
		target_color = s->cur_artwork.average;
		target_color = ColorContrast(target_color, 0.8);
		target_color = ColorBrightness(target_color, 0.6);
	}

	// TODO: color animates at the startup, but we don't want that
	float progress = 1.0 - ((float)s->transition_timer_ms / (float)TRANSITION_MS);
	s->transition_progress = progress;
	s->background = ColorLerp(s->prev_background, target_color, ease_in_out_sine(progress));
}

void state_set_artwork(State *s, Image image, Color average) {
	set_prev_artwork(s);

	// Update current artwork texture
	s->cur_artwork.texture = LoadTextureFromImage(image);
	SetTextureFilter(s->cur_artwork.texture, TEXTURE_FILTER_BILINEAR);
	s->cur_artwork.average = average;
	s->cur_artwork.exists = true;

	s->prev_background = s->background;
	s->transition_timer_ms = TRANSITION_MS;
}
void state_clear_artwork(State *s) {
	s->cur_artwork.exists = false;

	s->prev_background = s->background;
	s->transition_timer_ms = TRANSITION_MS;
}
Texture state_cur_artwork_texture(State *s) {
	if (s->cur_artwork.exists)
		return s->cur_artwork.texture;
	else
		return s->empty_artwork;
}
Texture state_prev_artwork_texture(State *s) {
	if (s->prev_artwork.exists)
		return s->prev_artwork.texture;
	else
		return s->empty_artwork;
}
