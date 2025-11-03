#ifndef ASSETS_H
#define ASSETS_H

#include <raylib.h>

typedef struct Assets {
	Font normal_font;
	Font title_font;

	// Spritesheet of icons
	Texture icons;
	// Spritesheet of NPatch thingies to draw fancy boxes/blocks
	Texture boxes;
	// Spritesheet of lines
	Texture lines;

	// Used if there is no album artwork of the currently playing song
	Texture empty_artwork;

} Assets;

Assets assets_new(void);

#endif
