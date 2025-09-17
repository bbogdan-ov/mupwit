#include "./queue_page.h"
#include "../macros.h"
#include "../draw.h"
#include "../theme.h"

#define SONG_PADDING 10
#define SONG_HEIGHT (THEME_NORMAL_TEXT_SIZE*2 + SONG_PADDING*2)

// TODO: focus on/scroll to the currently playing song

QueuePage queue_page_new() {
	return (QueuePage){
		.scrollable = scrollable_new(),
	};
}

void draw_song(Client *client, State *state, const struct mpd_song *song, Rect rect) {
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
		background = state->foreground;
		state->cursor = MOUSE_CURSOR_POINTING_HAND;
		draw_box(state, BOX_FILLED_ROUNDED, rect, background);
	}
	if (hover && IsMouseButtonPressed(MOUSE_BUTTON_LEFT)) {
		client_run_play_song(client, mpd_song_get_id(song));
	}

	// Show "currently playing" marker
	if (client->cur_song && mpd_song_get_id(client->cur_song) == mpd_song_get_id(song)) {
		draw_icon(
			state,
			ICON_SMALL_ARROW,
			vec(rect.x - ICON_SIZE/2, rect.y + rect.height/2 - ICON_SIZE/2),
			THEME_BLACK
		);
	}

	// Draw artwork placeholder
	// TODO: fetch and show the artwork for each song but first i need to
	// implement artwork caching
	Rect artwork_rect = {
		inner.x,
		inner.y + SONG_HEIGHT/2 - artwork_size/2,
		artwork_size,
		artwork_size
	};
	draw_box(state, BOX_NORMAL, artwork_rect, THEME_BLACK);
	draw_icon(
		state,
		ICON_DISK,
		vec(artwork_rect.x, artwork_rect.y),
		THEME_BLACK
	);
	inner.x += artwork_rect.width + SONG_PADDING;
	inner.width -= artwork_rect.width + SONG_PADDING;

	Text text = {
		.text = "",
		.font = state->normal_font,
		.size = THEME_NORMAL_TEXT_SIZE,
		.pos = {0},
		.color = THEME_SUBTLE_TEXT,
	};

	// Draw song duration
	// Is this ok to format duration string 60 times per song for each song in
	// the queue?..
	text.text = format_time(mpd_song_get_duration(song));
	Vec dur_size = measure_text(&text);
	text.pos = vec(
		inner.x + inner.width - dur_size.x,
		inner.y + SONG_HEIGHT/2 - dur_size.y/2
	);
	draw_text(text);
	inner.width -= dur_size.x;

	BeginScissorMode(inner.x, inner.y, inner.width, inner.height);

	// Draw song title
	text.text = song_tag_or_unknown(song, MPD_TAG_TITLE);
	text.color = THEME_TEXT;
	text.pos = vec(
		inner.x,
		inner.y + SONG_HEIGHT/2 - THEME_NORMAL_TEXT_SIZE
	);
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

	for (size_t i = 0; i < client->queue.len; i++) {
		const struct mpd_song *song = mpd_entity_get_song(client_get_queue_entity(client, i));

		Rect song_rect = rect(
			container.x,
			container.y - scroll + i * SONG_HEIGHT,
			container.width,
			SONG_HEIGHT
		);
		if (CheckCollisionRecs(song_rect, rect(0, 0, sw, sh)))
			draw_song(client, state, song, song_rect);
	}

	scrollable_set_height(&q->scrollable, client->queue.len * SONG_HEIGHT - container.height);

	UNLOCK(&client->mutex);
}
