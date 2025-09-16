#include <stdio.h>

#include "./queue_page.h"
#include "../macros.h"
#include "../draw.h"
#include "../theme.h"

#define SONG_PADDING 10
#define SONG_HEIGHT (THEME_NORMAL_TEXT_SIZE*2 + SONG_PADDING*2)

QueuePage queue_page_new() {
	return (QueuePage){
		.scrollable = scrollable_new(),
	};
}

void draw_song(State *state, const struct mpd_song *song, Rect rect) {
	int artwork_size = 32;

	Rect inner = (Rect){
		rect.x + SONG_PADDING,
		rect.y,
		rect.width - SONG_PADDING*2,
		rect.height
	};

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
		inner.y + SONG_HEIGHT/2 - artwork_size/2,
		artwork_size,
		artwork_size
	};
	draw_box(state, BOX_NORMAL, artwork_rect, THEME_BLACK);
	inner.width -= artwork_rect.width + SONG_PADDING;

	Text text = {
		.text = song_tag_or_unknown(song, MPD_TAG_TITLE),
		.font = state->normal_font,
		.size = THEME_NORMAL_TEXT_SIZE,
		.pos = vec(
			inner.x + artwork_rect.width + SONG_PADDING,
			inner.y + SONG_HEIGHT/2 - THEME_NORMAL_TEXT_SIZE
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
}

void queue_page_draw(QueuePage *q, Client *client, State *state) {
	// TODO: do not lock the client
	LOCK(&client->mutex);

	int sw = GetScreenWidth();
	int sh = GetScreenHeight();
	int padding = 8;

	Rect container = rect(
		padding,
		padding,
		sw - padding*2,
		sh - padding*2
	);

	scrollable_update(&q->scrollable);
	float scroll = scrollable_get_scroll(&q->scrollable);

	for (size_t i = 0; i < client->queue_len; i++) {
		const struct mpd_song *song = mpd_entity_get_song(client->queue[i]);

		Rect song_rect = rect(
			container.x,
			container.y - scroll + i * SONG_HEIGHT,
			container.width,
			SONG_HEIGHT
		);
		if (CheckCollisionRecs(song_rect, rect(0, 0, sw, sh)))
			draw_song(state, song, song_rect);
	}

	scrollable_set_height(&q->scrollable, client->queue_len * SONG_HEIGHT - container.height);

	UNLOCK(&client->mutex);
}
