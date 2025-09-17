#ifndef STATE_H
#define STATE_H

#include <raylib.h>

#include "./ui/tween.h"

typedef enum Page {
	PAGE_PLAYER,
	PAGE_QUEUE,
} Page;

typedef struct Artwork {
	bool exists;
	Texture texture;
	Color average;
} Artwork;

typedef struct State {
	Font normal_font;
	Font title_font;

	// Spritesheet of icons
	Texture icons;
	// Spritesheet of NPatch thingies to draw fancy boxes/blocks
	Texture boxes;

	// Used if there is no album artwork of the currently playing song
	Texture empty_artwork;

	// TODO: cache all the artworks by album name
	// Previously playing song album artwork
	Artwork prev_artwork;
	// Currently playing song album artwork
	Artwork cur_artwork;
	Tween artwork_tween;

	MouseCursor cursor;

	Color background;
	Color prev_background;
	Tween background_tween;

	Page page;
} State;

State state_new(void);

void state_update(State *s);

void state_set_artwork(State *s, Image image, Color average);
void state_clear_artwork(State *s);

void state_next_page(State *s);
void state_prev_page(State *s);

#endif
