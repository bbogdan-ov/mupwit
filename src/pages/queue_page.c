#include <string.h>

#include "./queue_page.h"
#include "../macros.h"
#include "../draw.h"
#include "../theme.h"
#include "../dynamic_array.h"

#define ENTRY_PADDING 10
#define ENTRY_HEIGHT (THEME_NORMAL_TEXT_SIZE*2 + ENTRY_PADDING*2)

// TODO: focus on/scroll to the currently playing song

QueuePage queue_page_new() {
	return (QueuePage){
		.entries = (QueueEntriesList)DA_ALLOC(512, sizeof(QueueEntry)),

		.scrollable = scrollable_new(),
	};
}

QueueEntry entry_new(struct mpd_entity *entity, size_t idx) {
	const struct mpd_song *song = mpd_entity_get_song(entity);

	const char *text = format_time(mpd_song_get_duration(song));
	size_t len = strlen(text) + 1;
	char *duration_text = malloc(len);
	memcpy(duration_text, text, len);

	return (QueueEntry){
		.pos_y = idx * ENTRY_HEIGHT,
		.song = song,
		.duration_text = duration_text,
	};
}
void entry_free(QueueEntry *entry) {
	if (entry->duration_text) {
		free(entry->duration_text);
		entry->duration_text = NULL;
	}
}

void entry_draw(QueueEntry *entry, Client *client, State *state, Rect rect) {
	int artwork_size = 32;

	Rect inner = (Rect){
		rect.x + ENTRY_PADDING,
		rect.y,
		rect.width - ENTRY_PADDING*2,
		rect.height
	};

	Color background = state->background;

	bool hover = CheckCollisionPointRec(GetMousePosition(), rect);
	if (hover) {
		background = state->foreground;
		state->cursor = MOUSE_CURSOR_POINTING_HAND;
		draw_box(state, BOX_FILLED_ROUNDED, rect, background);
	}
	if (hover && IsMouseButtonReleased(MOUSE_BUTTON_LEFT)) {
		client_run_play_song(client, mpd_song_get_id(entry->song));
	}

	// Show "currently playing" marker
	if (client->cur_song && mpd_song_get_id(client->cur_song) == mpd_song_get_id(entry->song)) {
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
		inner.y + ENTRY_HEIGHT/2 - artwork_size/2,
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
	inner.x += artwork_rect.width + ENTRY_PADDING;
	inner.width -= artwork_rect.width + ENTRY_PADDING;

	Text text = {
		.text = "",
		.font = state->normal_font,
		.size = THEME_NORMAL_TEXT_SIZE,
		.pos = {0},
		.color = THEME_SUBTLE_TEXT,
	};

	// Draw song duration
	text.text = entry->duration_text;
	Vec dur_size = measure_text(&text);
	text.pos = vec(
		inner.x + inner.width - dur_size.x,
		inner.y + ENTRY_HEIGHT/2 - dur_size.y/2
	);
	draw_text(text);
	inner.width -= dur_size.x;

	BeginScissorMode(inner.x, inner.y, inner.width, inner.height);

	// Draw song title
	text.text = song_tag_or_unknown(entry->song, MPD_TAG_TITLE);
	text.color = THEME_TEXT;
	text.pos = vec(
		inner.x,
		inner.y + ENTRY_HEIGHT/2 - THEME_NORMAL_TEXT_SIZE
	);
	draw_cropped_text(text, inner.width, background);
	text.pos.y += THEME_NORMAL_TEXT_SIZE;

	// Draw song artist
	text.text = song_tag_or_unknown(entry->song, MPD_TAG_ARTIST);
	text.color = THEME_SUBTLE_TEXT;
	draw_cropped_text(text, inner.width, background);

	EndScissorMode();
}

void rebuild_entries(QueuePage *q, Client *client) {
	// Clean up previous queue entries
	for (size_t i = 0; i < q->entries.len; i++) {
		entry_free(&q->entries.items[i]);
	}

	q->entries.len = 0;
	DA_RESERVE(&q->entries, client->queue.len);
	for (size_t i = 0; i < client->queue.len; i++) {
		DA_PUSH(&q->entries, entry_new(client->queue.items[i], i));
	}
}

void queue_page_update(QueuePage *q, Client *client) {
	// TODO: do not lock the client
	LOCK(&client->mutex);

	if (client->queue_just_changed) {
		rebuild_entries(q, client);
	}

	UNLOCK(&client->mutex);
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

	for (size_t i = 0; i < q->entries.len; i++) {
		QueueEntry *entry = &q->entries.items[i];

		Rect song_rect = rect(
			container.x,
			container.y - scroll + entry->pos_y,
			container.width,
			ENTRY_HEIGHT
		);
		if (CheckCollisionRecs(song_rect, rect(0, 0, sw, sh)))
			entry_draw(entry, client, state, song_rect);
	}

	scrollable_set_height(&q->scrollable, client->queue.len * ENTRY_HEIGHT - container.height);

	UNLOCK(&client->mutex);
}
