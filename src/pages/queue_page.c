#include <raylib.h>

#include "./queue_page.h"
#include "../macros.h"
#include "../draw.h"
#include "../theme.h"

float draw_song(State *state, const struct mpd_song *song, Rect container) {
	int padding = 10;
	int artwork_size = 32;
	int height = THEME_NORMAL_TEXT_SIZE*2 + padding*2;

	Rect rect = (Rect){container.x, container.y, container.width, height};
	Rect inner = (Rect){rect.x + padding, rect.y, rect.width - padding*2, rect.height};

	Color background = state->background;

	bool hover = CheckCollisionPointRec(GetMousePosition(), rect);
	if (hover) {
		background = ColorContrast(state->background, 0.3);
		state->cursor = MOUSE_CURSOR_POINTING_HAND;

		draw_box(state, BOX_FILLED_ROUNDED, rect, background);
	}

	BeginScissorMode(inner.x, inner.y, inner.width, inner.height);

	// Draw artwork placeholder
	Rect artwork_rect = {
		inner.x,
		inner.y + height/2 - artwork_size/2,
		artwork_size,
		artwork_size
	};
	draw_box(state, BOX_NORMAL, artwork_rect, THEME_BLACK);
	inner.width -= artwork_rect.width + padding;

	Text text = {
		.text = song_tag_or_unknown(song, MPD_TAG_TITLE),
		.font = state->normal_font,
		.size = THEME_NORMAL_TEXT_SIZE,
		.pos = vec(
			inner.x + artwork_rect.width + padding,
			inner.y + height/2 - THEME_NORMAL_TEXT_SIZE
		),
		.color = THEME_BLACK,
	};

	// Draw song title
	draw_cropped_text(text, inner.width, background);
	text.pos.y += THEME_NORMAL_TEXT_SIZE;

	// Draw song artist
	text.text = song_tag_or_unknown(song, MPD_TAG_ARTIST);
	text.color = THEME_SUBTLE_TEXT;
	draw_cropped_text(text, inner.width, background);

	EndScissorMode();

	return height;
}

void queue_page_draw(Client *client, State *state) {
	// TODO: do not lock the client
	LOCK(&client->mutex);

	int sw = GetScreenWidth();
	int sh = GetScreenHeight();
	int padding = 8;

	float offset_y = padding;
	for (size_t i = 0; i < client->queue_len; i++) {
		const struct mpd_song *song = mpd_entity_get_song(client->queue[i]);

		float height = draw_song(
			state,
			song,
			rect(
				padding,
				offset_y,
				sw - padding*2,
				sh - padding*2
			)
		);
		offset_y += height;
	}

	UNLOCK(&client->mutex);
}
