#include <assert.h>
#include <math.h>

#include "./theme.h"
#include "./state.h"
#include "./macros.h"

#include <raymath.h>

static Color calc_foreground(Color bg) {
	return ColorBrightness(bg, -0.15);
}

State state_new(void) {
	return (State){
		.prev_artwork = artwork_image_new(),
		.cur_artwork = artwork_image_new(),
		.cur_artwork_image = (Image){0},

		.foreground = calc_foreground(THEME_BACKGROUND),
		.background = THEME_BACKGROUND,
		.prev_background = THEME_BACKGROUND,
		.background_tween = tween_new(1000),

		.page = PAGE_PLAYER,
		.prev_page = 0,
		.page_tween = tween_new(200),
		.page_transition = 1.0,
	};
}

static void _state_start_background_tween(State *s) {
	s->prev_background = s->background;
	s->background_tween_finished = false;
	tween_play(&s->background_tween);
}

static void _state_set_page(State *s, Page page) {
	s->prev_page = s->page;
	s->page = page;

	s->prev_page_transition = 1.0 - s->page_transition;
	tween_play(&s->page_tween);
}

void state_update(State *s, Client *client) {
	tween_update(&s->background_tween);
	tween_update(&s->page_tween);

	// TODO: refactor this code
	Image image = {0};
	Color cur_color = s->cur_artwork.color;
	bool cur_exists = s->cur_artwork.exists;
	bool artwork_updated = artwork_image_update(&s->cur_artwork, client, &image);
	if (artwork_updated) {
		if (cur_exists) {
			if (s->cur_artwork_image.data != NULL) {
				update_texture_from_image(&s->prev_artwork.texture, s->cur_artwork_image);
				UnloadImage(s->cur_artwork_image);
				s->cur_artwork_image = (Image){0};
			}

			s->prev_artwork.color = cur_color;
			s->prev_artwork.exists = true;
		} else {
			if (s->cur_artwork_image.data != NULL) {
				UnloadImage(s->cur_artwork_image);
				s->cur_artwork_image = (Image){0};
			}

			s->prev_artwork.exists = false;
		}

		s->cur_artwork_image = image;
		_state_start_background_tween(s);
	}

	// Request artwork of the currently playing song
	static bool initialized = false;
	if (!initialized || client->events & EVENT_SONG_CHANGED) {
		// TODO!!: add delay between artwork requests, a.k.a ✨"debounce"✨ if you are a web dev

		const struct mpd_song *cur_song_nullable;
		client_lock_status_nullable(client, &cur_song_nullable, NULL);

		if (cur_song_nullable) {
			const char *song_uri = mpd_song_get_uri(cur_song_nullable);
			artwork_image_fetch(&s->cur_artwork, client, song_uri);
		}

		client_unlock_status(client);
		initialized = true;
	}

	// Update background animation
	if (!s->background_tween_finished) {
		Color target_color = THEME_BACKGROUND;
		if (s->cur_artwork.exists) {
			target_color = s->cur_artwork.color;
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
			s->background = target_color;
			s->foreground = calc_foreground(s->background);
			s->background_tween_finished = true;
		}
	}

	// Update page animation
	if (tween_playing(&s->page_tween))
		s->page_transition = Lerp(
			s->prev_page_transition,
			1.0,
			EASE_IN_OUT_QUAD(tween_progress(&s->page_tween))
		);
	else
		s->page_transition = 1.0;
}

void state_next_page(State *s) {
	switch (s->page) {
		case PAGE_PLAYER: _state_set_page(s, PAGE_QUEUE); break;
		case PAGE_QUEUE: _state_set_page(s, PAGE_PLAYER); break;
		case PAGE_ALBUMS: TODO("switch to player page"); break;
	}
}
void state_prev_page(State *s) {
	switch (s->page) {
		case PAGE_PLAYER: _state_set_page(s, PAGE_QUEUE); break;
		case PAGE_QUEUE: _state_set_page(s, PAGE_PLAYER); break;
		case PAGE_ALBUMS: TODO("switch to queue page"); break;
	}
}

float state_artwork_alpha(State *s) {
	return MIN(tween_progress(&s->background_tween) * 6.0, 1.0);
}

void state_free(State *s) {
	if (s->cur_artwork_image.data)
		UnloadImage(s->cur_artwork_image);
}
