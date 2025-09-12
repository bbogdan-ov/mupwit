#include <assert.h>
#include <math.h>

#include "./theme.h"
#include "./state.h"

#include "../build/assets.h"

#define IMAGE(NAME) (Image){NAME ## _DATA, NAME ## _WIDTH,  NAME ## _HEIGHT, 1, NAME ## _PIXEL_FORMAT}
#define TEXTURE(NAME) LoadTextureFromImage(IMAGE(NAME))

State state_new(void) {
	// Create fonts
	Image image = (Image){code9x7_IMAGE_DATA, code9x7_IMAGE_WIDTH, code9x7_IMAGE_HEIGHT, 1, code9x7_PIXEL_FORMAT};
	Texture texture = LoadTextureFromImage(image);
	Font normal_font = (Font) {
		.baseSize = code9x7_BASE_SIZE,
		.glyphCount = code9x7_GLYPH_COUNT,
		.glyphPadding = code9x7_GLYPH_PADDING,
		.texture = texture,
		.recs = code9x7_RECTS,
		.glyphs = code9x7_GLYPHS,
	};

	image = (Image){comicoro_IMAGE_DATA, comicoro_IMAGE_WIDTH,  comicoro_IMAGE_HEIGHT, 1, comicoro_PIXEL_FORMAT};
	texture = LoadTextureFromImage(image);
	Font title_font = (Font) {
		.baseSize = comicoro_BASE_SIZE,
		.glyphCount = comicoro_GLYPH_COUNT,
		.glyphPadding = comicoro_GLYPH_PADDING,
		.texture = texture,
		.recs = comicoro_RECTS,
		.glyphs = comicoro_GLYPHS,
	};

	// Load empty artwork texture
	Texture empty_artwork = TEXTURE(empty_artwork);
	SetTextureFilter(empty_artwork, TEXTURE_FILTER_BILINEAR);

	return (State){
		.normal_font = normal_font,
		.title_font = title_font,

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
