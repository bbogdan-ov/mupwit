#include <string.h>

#include "./queue_page.h"
#include "../macros.h"
#include "../draw.h"
#include "../theme.h"
#include "../dynamic_array.h"

#include <raymath.h>

#define ENTRY_PADDING 10
#define ARTWORK_SIZE 32
#define ENTRY_HEIGHT (ARTWORK_SIZE + ENTRY_PADDING*2)

// TODO: focus on/scroll to the currently playing song
// TODO: draw "no songs" when queue is empty

QueuePage queue_page_new() {
	return (QueuePage){
		.entries = (QueueEntriesList){0},
		.reordering_idx = -1,

		.scrollable = scrollable_new(),
	};
}

QueueEntry entry_new(struct mpd_entity *entity, size_t number) {
	const struct mpd_song *song = mpd_entity_get_song(entity);

	const char *text = format_time(mpd_song_get_duration(song));
	size_t len = strlen(text) + 1;
	char *duration_text = malloc(len);
	memcpy(duration_text, text, len);

	return (QueueEntry){
		.number = number,

		.pos_y = number * ENTRY_HEIGHT,
		.prev_pos_y = number * ENTRY_HEIGHT,
		.pos_tween = tween_new(200),

		.entity = entity,
		.duration_text = duration_text,
	};
}
void entry_free(QueueEntry *e) {
	if (e->duration_text) {
		free(e->duration_text);
		e->duration_text = NULL;
	}
	if (e->entity) {
		mpd_entity_free(e->entity);
		e->entity = NULL;
	}
}

void entry_tween_to_rest(QueueEntry *e) {
	e->prev_pos_y = e->pos_y;
	tween_play(&e->pos_tween);
}

void entry_draw(int idx, QueueEntry *entry, QueuePage *queue, Client *client, State *state) {
	Rect rect = (Rect){
		state->container.x,
		state->container.y - state->scroll + entry->pos_y,
		state->container.width,
		ENTRY_HEIGHT
	};

	// Draw only visible entries
	if (!CheckCollisionRecs(rect, screen_rect())) return;

	const struct mpd_song *song = mpd_entity_get_song(entry->entity);

	Rect inner = rect_shrink(rect, ENTRY_PADDING, 0);
	Color background = state->background;

	bool is_hovering = CheckCollisionPointRec(GetMousePosition(), rect);
	bool is_reordering = queue->reordering_idx == idx;

	// Draw background when hovering over or reordering the entry
	if ((is_hovering && queue->reordering_idx < 0) || is_reordering) {
		background = state->foreground;
		state->cursor = MOUSE_CURSOR_POINTING_HAND;
		draw_box(state, BOX_FILLED_ROUNDED, rect, background);
	}

	if (is_hovering && queue->reordering_idx < 0 && IsMouseButtonPressed(MOUSE_BUTTON_LEFT)) {
		// Start reordering
		queue->reordering_idx = idx;
		queue->reordered_from_number = entry->number;
		queue->reorder_click_offset_y = GetMouseY() - rect.y;
	}
	// if (is_hovering && IsMouseButtonReleased(MOUSE_BUTTON_LEFT)) {
	// 	client_run_play_song(client, mpd_song_get_id(song));
	// }

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
		inner.y + ENTRY_HEIGHT/2 - ARTWORK_SIZE/2,
		ARTWORK_SIZE,
		ARTWORK_SIZE
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
	inner.width -= dur_size.x + ENTRY_PADDING;

	BeginScissorMode(inner.x, inner.y, inner.width, inner.height);

	// Draw song title
	text.text = song_tag_or_unknown(song, MPD_TAG_TITLE);
	text.color = THEME_TEXT;
	text.pos = vec(
		inner.x,
		inner.y + ENTRY_HEIGHT/2 - THEME_NORMAL_TEXT_SIZE
	);
	draw_cropped_text(text, inner.width, background);
	text.pos.y += THEME_NORMAL_TEXT_SIZE;

	// Draw song artist
	text.text = song_tag_or_unknown(song, MPD_TAG_ARTIST);
	text.color = THEME_SUBTLE_TEXT;
	draw_cropped_text(text, inner.width, background);

	EndScissorMode();
}

void fetch_queue(QueuePage *q, Client *client) {
	bool res = mpd_send_list_queue_meta(client->conn);
	if (!res) {
		CONN_HANDLE_ERROR(client->conn);
		return;
	}

	queue_page_free(q);
	DA_RESERVE(&q->entries, 512);

	// Receive queue entities/songs from the server
	while (true) {
		struct mpd_entity *entity = mpd_recv_entity(client->conn);
		if (entity == NULL) {
			CONN_HANDLE_ERROR(client->conn);
			break;
		}

		enum mpd_entity_type typ = mpd_entity_get_type(entity);
		if (typ == MPD_ENTITY_TYPE_SONG) {
			// Push the received song entity into the queue dynamic array
			size_t idx = q->entries.len;
			DA_PUSH(&q->entries, entry_new(entity, idx));
		}
	}
}

void queue_page_update(QueuePage *q, Client *client) {
	// TODO!: fetch the queue when 'playlist' idle is received
	if (q->entries.len > 0) return;

	LOCK(&client->mutex);

	// TODO: fetch queue asynchronously or in a separate thread
	fetch_queue(q, client);

	UNLOCK(&client->mutex);
}

void draw_reordering_entry(QueuePage *q, Client *client, State *state) {
	if (q->reordering_idx < 0) return;

	QueueEntry *reordering = &q->entries.items[q->reordering_idx];

	float offset_y = state->container.y - state->scroll;
	float new_pos_y = GetMouseY() - q->reorder_click_offset_y - offset_y;

	int new_number = (int)((new_pos_y + ENTRY_HEIGHT/2) / ENTRY_HEIGHT);

	int from_number = 0;
	int to_number = 0;
	int move_by = 0;
	if (new_number > reordering->number) {
		// Entry was moved down
		from_number = reordering->number;
		to_number = new_number;
		move_by = -1;
	} else if (new_number < reordering->number) {
		// Entry was moved up
		from_number = new_number;
		to_number = reordering->number;
		move_by = 1;
	}

	if (move_by != 0) {
		// Reorder all entries inside range `from_number`-`to_number`
		for (size_t i = 0; i < q->entries.len; i++) {
			if ((int)i == q->reordering_idx) continue;

			QueueEntry *another = &q->entries.items[i];

			if (another->number >= from_number && another->number <= to_number) {
				int new_number = another->number + move_by;
				if (new_number >= 0 && new_number < (int)q->entries.len) {
					another->number = new_number;
					entry_tween_to_rest(another);
				}
			}
		}

		reordering->number = CLAMP(new_number, 0, q->entries.len - 1);
	}

	reordering->pos_y = new_pos_y;

	// Scroll follows currently reordering entry
	float relative_pos_y = reordering->pos_y - state->scroll;
	float top = (relative_pos_y + 0) - 0;
	float bottom = (relative_pos_y + ENTRY_HEIGHT) - state->container.height;
	if (top < 0.0)    q->scrollable.target_scroll += top / 3.0;
	if (bottom > 0.0) q->scrollable.target_scroll += bottom / 3.0;

	entry_draw(q->reordering_idx, reordering, q, client, state);

	// Reordering stopped
	if (!IsMouseButtonDown(MOUSE_BUTTON_LEFT)) {
		bool res = client_run_reorder(client, q->reordered_from_number, reordering->number);
		if (!res) {
			TraceLog(LOG_ERROR, "QUEUE: Unable to reorder, discarding");

			new_number = q->reordered_from_number;
			if (new_number > reordering->number) {
				// Entry was moved down
				from_number = reordering->number;
				to_number = new_number;
				move_by = -1;
			} else if (new_number < reordering->number) {
				// Entry was moved up
				from_number = new_number;
				to_number = reordering->number;
				move_by = 1;
			}

			// Reorder all entries inside range `from_number`-`to_number`
			for (size_t i = 0; i < q->entries.len; i++) {
				if ((int)i == q->reordering_idx) continue;

				QueueEntry *another = &q->entries.items[i];

				if (another->number >= from_number && another->number <= to_number) {
					int new_number = another->number + move_by;
					if (new_number >= 0 && new_number < (int)q->entries.len) {
						another->number = new_number;
						entry_tween_to_rest(another);
					}
				}
			}

			reordering->number = new_number;
		}

		entry_tween_to_rest(reordering);
		q->reordering_idx = -1;
	}
}

void queue_page_draw(QueuePage *q, Client *client, State *state) {
	LOCK(&client->mutex);

	int sw = GetScreenWidth();
	int sh = GetScreenHeight();
	int padding = 8;

	scrollable_update(&q->scrollable);

	state->scroll = q->scrollable.scroll;
	state->container = rect(
		padding,
		padding,
		sw - padding*2,
		sh - padding*2
	);

	// Draw the entries
	for (size_t i = 0; i < q->entries.len; i++) {
		if ((int)i == q->reordering_idx) continue;

		QueueEntry *entry = &q->entries.items[i];

		tween_update(&entry->pos_tween);
		float target_pos_y = entry->number * ENTRY_HEIGHT;
		entry->pos_y = Lerp(
			entry->prev_pos_y,
			target_pos_y,
			EASE_OUT_CUBIC(tween_progress(&entry->pos_tween))
		);

		entry_draw((int)i, entry, q, client, state);
	}

	// Draw entry that is currently being reordered
	draw_reordering_entry(q, client, state);

	scrollable_set_height(
		&q->scrollable,
		q->entries.len * ENTRY_HEIGHT - state->container.height
	);

	UNLOCK(&client->mutex);
}

void queue_page_free(QueuePage *q) {
	for (size_t i = 0; i < q->entries.len; i++) {
		entry_free(&q->entries.items[i]);
	}
	q->entries.len = 0;
}
