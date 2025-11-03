#include <assert.h>
#include <math.h>

#include "./theme.h"
#include "./state.h"
#include "./macros.h"

#include <raymath.h>

#define ARTWORK_FETCH_DELAY_MS 150

static Color calc_foreground(Color bg) {
	return ColorBrightness(bg, -0.15);
}

State state_new(void) {
	return (State){
		.prev_artwork = artwork_image_new(),
		.cur_artwork = artwork_image_new(),
		.cur_artwork_image = (Image){0},
		.artwork_fetch_timer = timer_new(ARTWORK_FETCH_DELAY_MS, false),

		.foreground = calc_foreground(THEME_BACKGROUND),
		.background = THEME_BACKGROUND,
		.prev_background = THEME_BACKGROUND,
		.background_tween = timer_new(1000, false),

		.page = PAGE_PLAYER,
		.prev_page = 0,
		.page_tween = timer_new(200, false),
		.page_transition = 1.0,
	};
}

static void _state_start_background_tween(State *s) {
	s->prev_background = s->background;
	timer_play(&s->background_tween);
}

static void _state_set_page(State *s, Page page) {
	s->prev_page = s->page;
	s->page = page;

	s->prev_page_transition = 1.0 - s->page_transition;
	timer_play(&s->page_tween);
}

static void _state_set_prev_artwork(State *s) {
	if (!s->cur_artwork.exists) {
		if (s->cur_artwork_image.data != NULL) {
			UnloadImage(s->cur_artwork_image);
			s->cur_artwork_image = (Image){0};
		}

		s->prev_artwork.exists = false;
		return;
	}

	if (s->cur_artwork_image.data != NULL) {
		update_texture_from_image(&s->prev_artwork.texture, s->cur_artwork_image);
		UnloadImage(s->cur_artwork_image);
		s->cur_artwork_image = (Image){0};
	}

	s->prev_artwork.color = s->cur_artwork.color;
	s->prev_artwork.exists = true;
}

static void _state_update_artworks(State *s, Client *client) {
	Image image = {0};
	Color color = {0};
	bool artwork_received = artwork_image_poll(&s->cur_artwork, client, &image, &color);
	if (!artwork_received) return;

	_state_set_prev_artwork(s);
	_state_start_background_tween(s);

	artwork_image_update(&s->cur_artwork, image, color);

	s->cur_artwork_image = image;
}

static void _state_update_artwork_fetching(State *s, Client *client) {
	if (s->fetch_artwork_on_timer_finish && timer_finished(&s->artwork_fetch_timer)) {
		const struct mpd_song *cur_song_nullable;
		client_lock_status_nullable(client, &cur_song_nullable, NULL);

		if (cur_song_nullable) {
			const char *song_uri = mpd_song_get_uri(cur_song_nullable);
			artwork_image_fetch(&s->cur_artwork, client, song_uri);
		}

		client_unlock_status(client);
		s->fetch_artwork_on_timer_finish = false;
	}

	static bool first = true;
	if (!first && (client->events & EVENT_SONG_CHANGED) == 0) return;

	timer_play(&s->artwork_fetch_timer);
	s->fetch_artwork_on_timer_finish = true;

	first = false;
}

void state_update(State *s, Client *client) {
	timer_update(&s->background_tween);
	timer_update(&s->page_tween);
	timer_update(&s->artwork_fetch_timer);

	_state_update_artworks(s, client);
	_state_update_artwork_fetching(s, client);

	// Update background animation
	if (!timer_finished(&s->background_tween)) {
		Color target_color = THEME_BACKGROUND;
		if (s->cur_artwork.exists) {
			target_color = s->cur_artwork.color;
		}

		if (timer_playing(&s->background_tween)) {
			float progress = timer_progress(&s->background_tween);
			s->background = ColorLerp(
				s->prev_background,
				target_color,
				EASE_IN_OUT_SINE(progress)
			);
			s->foreground = calc_foreground(s->background);
		} else {
			s->background = target_color;
			s->foreground = calc_foreground(s->background);
		}
	}

	// Update page animation
	if (timer_playing(&s->page_tween))
		s->page_transition = Lerp(
			s->prev_page_transition,
			1.0,
			EASE_IN_OUT_QUAD(timer_progress(&s->page_tween))
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
	return MIN(timer_progress(&s->background_tween) * 6.0, 1.0);
}

void state_free(State *s) {
	if (s->cur_artwork_image.data)
		UnloadImage(s->cur_artwork_image);
}
