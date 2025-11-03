#include "./assets.h"

#include <stdio.h>
#include "../build/assets.h"

#define FONT(NAME) (Font){ \
		.baseSize = NAME ## _BASE_SIZE, \
		.glyphCount = NAME ## _GLYPH_COUNT, \
		.glyphPadding = NAME ## _GLYPH_PADDING, \
		.texture = LoadTextureFromImage( \
			(Image){ \
				.data    = NAME ## _IMAGE_DATA, \
				.width   = NAME ## _IMAGE_WIDTH, \
				.height  = NAME ## _IMAGE_HEIGHT, \
				.mipmaps = 1, \
				.format  = NAME ## _PIXEL_FORMAT \
			} \
		), \
		.recs = NAME ## _RECTS, \
		.glyphs = NAME ## _GLYPHS, \
	}

#define TEXTURE(NAME) LoadTextureFromImage( \
	(Image){ \
		.data    = NAME ## _DATA, \
		.width   = NAME ## _WIDTH, \
		.height  = NAME ## _HEIGHT, \
		.mipmaps = 1, \
		.format  = NAME ## _PIXEL_FORMAT \
	})

Assets assets_new(void) {
	return (Assets){
		.normal_font = FONT(code9x7),
		.title_font = FONT(comicoro),

		.icons = TEXTURE(icons),
		.boxes = TEXTURE(boxes),
		.lines = TEXTURE(lines),

		.empty_artwork = TEXTURE(empty_artwork),
	};
}
