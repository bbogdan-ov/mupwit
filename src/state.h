#ifndef STATE_H
#define STATE_H

#include <raylib.h>

#include "./client.h"
#include "./ui/timer.h"
#include "./ui/artwork_image.h"

typedef enum Page {
	PAGE_PLAYER = 1,
	PAGE_QUEUE,
	PAGE_ALBUMS,
} Page;

typedef struct State {
	// TODO: cache all the artworks by album name

	// Previously playing song album artwork
	ArtworkImage prev_artwork;
	// Currently playing song album artwork
	ArtworkImage cur_artwork;
	// Image data of the current artwork image
	Image cur_artwork_image;
	Timer artwork_fetch_timer;
	bool fetch_artwork_on_timer_finish;

	MouseCursor cursor;

	Color foreground;
	Color background;
	Color prev_background;
	Timer background_tween;

	Page page;
	Page prev_page;
	Timer page_tween;
	float page_transition;
	float prev_page_transition;

	// Current rectangle in which things are being drawn
	Rectangle container;
	// Current scroll Y offset
	float scroll;
} State;

State state_new(void);

void state_update(State *s, Client *client);

void state_next_page(State *s);
void state_prev_page(State *s);

float state_artwork_alpha(State *s);

void state_free(State *s);

#endif
