#ifndef STATE_H
#define STATE_H

#include <raylib.h>

#define TRANSITION_MS 1000

typedef struct Artwork {
	bool exists;
	Texture texture;
	Color average;
} Artwork;

typedef struct State {
	Font normal_font;
	Font title_font;

	// Spritesheet of 16x16 icons
	Texture icons;
	// Spritesheet of 9x9 NPatch thingies
	Texture npatches;

	// Used if there is no album artwork of the currently playing song
	Texture empty_artwork;

	// TODO: cache all the artworks by album name
	// Previously playing song album artwork
	Artwork prev_artwork;
	// Currently playing song album artwork
	Artwork cur_artwork;

	Color background;
	Color prev_background;
	int transition_timer_ms;
	float transition_progress;
} State;

State state_new(void);

void state_update(State *s);

void state_set_artwork(State *s, Image image, Color average);
void state_clear_artwork(State *s);
Texture state_cur_artwork_texture(State *s);
Texture state_prev_artwork_texture(State *s);

#endif
