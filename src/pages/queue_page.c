#include <string.h>

#include "./queue_page.h"
#include "../macros.h"
#include "../theme.h"
#include "../macros.h"
#include "../ui/draw.h"
#include "../ui/currently_playing.h"

#include <raymath.h>

#define PADDING 8

#define ARTWORK_SIZE 32
#define ENTRY_HEIGHT (ARTWORK_SIZE + PADDING*2)

#define GRAB_THRESHOLD 8

// TODO: draw "no songs" when queue is empty

QueuePage queue_page_new() {
	return (QueuePage){
		.entries = (QueueEntriesList){0},
		.trying_to_grab_idx = -1,
		.reordering_idx = -1,

		.scrollable = scrollable_new(),
	};
}

QueueEntry entry_new(struct mpd_entity *entity, size_t number) {
	const struct mpd_song *song = mpd_entity_get_song(entity);

	const char *text = format_time(mpd_song_get_duration(song), false);
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
	e->pos_y = e->number * ENTRY_HEIGHT;
	tween_play(&e->pos_tween);
}

int entry_number_from_pos(QueueEntry *e) {
	return (int)((e->pos_y + ENTRY_HEIGHT / 2) / ENTRY_HEIGHT);
}

void entry_draw(int idx, QueueEntry *entry, QueuePage *queue, Client *client, State *state) {
#define IS_REORDERING (queue->reordering_idx == idx)
#define IS_TRYING_TO_GRAB (queue->trying_to_grab_idx == idx)

	Rect rect = {
		state->container.x,
		state->container.y - state->scroll + entry->pos_y,
		state->container.width,
		ENTRY_HEIGHT
	};

	// Draw only visible entries
	if (!CheckCollisionRecs(rect, screen_rect())) return;

	tween_update(&entry->pos_tween);
	float pos_y = Lerp(
		entry->prev_pos_y,
		entry->pos_y,
		EASE_OUT_CUBIC(tween_progress(&entry->pos_tween))
	);
	rect.y = state->container.y - state->scroll + pos_y;

	const struct mpd_song *song = mpd_entity_get_song(entry->entity);

	Rect inner = rect_shrink(rect, PADDING, 0);
	Color background = state->background;

	// ==============================
	// Entry events
	// ==============================

	bool is_playing = song_is_playing(client, song);
	Vec mouse_pos = get_mouse_pos();
	bool is_hovering = CheckCollisionPointRec(mouse_pos, rect);
	is_hovering = is_hovering && CheckCollisionPointRec(mouse_pos, state->container);

	// Clicking on entry will start "trying to grab mode"
	if (is_hovering && queue->reordering_idx < 0 && IsMouseButtonPressed(MOUSE_BUTTON_LEFT)) {
		queue->trying_to_grab_idx = idx;
		queue->reorder_click_offset_y = GetMouseY() - rect.y;
	}

	if (IS_TRYING_TO_GRAB) {
		// If we dragged more than `GRAB_THRESHOLD` from the
		// previous click position...
		float diff = queue->reorder_click_offset_y + rect.y - GetMouseY();
		if (fabs(diff) > GRAB_THRESHOLD) {
			// Start reordering
			entry->prev_pos_y = entry->pos_y;
			tween_play(&entry->pos_tween);

			queue->trying_to_grab_idx = -1;
			queue->reordering_idx = idx;
			queue->reordered_from_number = entry->number;
		}

		// Stop "trying to grab mode"
		if (!IsMouseButtonDown(MOUSE_BUTTON_LEFT)) {
			queue->trying_to_grab_idx = -1;
		}
	}

	// Releasing mouse button will play this song
	if (
		!is_playing
		&& is_hovering
		&& queue->reordering_idx < 0
		&& IsMouseButtonReleased(MOUSE_BUTTON_LEFT)
	) {
		unsigned song_id = mpd_song_get_id(song);
		client_push_action(client, (Action){ACTION_PLAY_SONG, {.song_id = song_id}});
	}

	// ==============================
	// Draw entry
	// ==============================

	// Draw background when hovering over or reordering the entry
	if (
		(is_hovering && queue->reordering_idx < 0 && queue->trying_to_grab_idx < 0)
		|| IS_REORDERING
		|| IS_TRYING_TO_GRAB
	) {
		background = state->foreground;
		state->cursor = MOUSE_CURSOR_POINTING_HAND;
		draw_box(state, BOX_FILLED_ROUNDED, rect, background);
	}

	// Show "currently playing" marker
	if (is_playing) {
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
	draw_icon(
		state,
		ICON_DISK,
		vec(
			artwork_rect.x + artwork_rect.width/2 - ICON_SIZE/2,
			artwork_rect.y + artwork_rect.height/2 - ICON_SIZE/2
		),
		THEME_BLACK
	);
	draw_box(state, BOX_NORMAL, artwork_rect, THEME_BLACK);
	inner.x += artwork_rect.width + PADDING;
	inner.width -= artwork_rect.width + PADDING;

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
	inner.width -= dur_size.x + PADDING;

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

// Reorder entry UI element, does NOT affect an actual queue.
// Any entry reordering also does NOT affect the order of items in the array (`entries`)
void queue_reorder_entry(QueuePage *q, QueueEntry *entry, int to_number) {
	to_number = CLAMP(to_number, 0, q->entries.len - 1);

	int range_from = 0;
	int range_to = 0;
	int move_by = 0;

	if (to_number > entry->number) {
		// Entry was moved down
		range_from = entry->number;
		range_to = to_number;
		move_by = -1;
	} else if (to_number < entry->number) {
		// Entry was moved up
		range_from = to_number;
		range_to = entry->number;
		move_by = 1;
	}

	if (move_by == 0) return;

	// Reorder all entries inside range `range_from`-`range_to`
	for (size_t i = 0; i < q->entries.len; i++) {
		if ((int)i == q->reordering_idx) continue;

		QueueEntry *another = &q->entries.items[i];

		if (another->number >= range_from && another->number <= range_to) {
			int moved_number = another->number + move_by;
			if (moved_number >= 0 && moved_number < (int)q->entries.len) {
				another->number = moved_number;
				entry_tween_to_rest(another);
			}
		}
	}

	entry->number = to_number;
}

void fetch_queue(QueuePage *q, Client *client) {
	bool res = mpd_send_list_queue_meta(client->_conn);
	if (!res) {
		CONN_HANDLE_ERROR(client->_conn);
		return;
	}

	// Free previous entries
	for (size_t i = 0; i < q->entries.len; i++) {
		entry_free(&q->entries.items[i]);
	}
	q->entries.len = 0;
	q->total_duration = 0;

	DA_RESERVE(&q->entries, 512);

	// Receive queue entities/songs from the server
	while (true) {
		struct mpd_entity *entity = mpd_recv_entity(client->_conn);
		if (entity == NULL) {
			CONN_HANDLE_ERROR(client->_conn);
			break;
		}

		enum mpd_entity_type typ = mpd_entity_get_type(entity);
		if (typ == MPD_ENTITY_TYPE_SONG) {
			// Push the received song entity into the queue dynamic array
			size_t idx = q->entries.len;
			DA_PUSH(&q->entries, entry_new(entity, idx));

			const struct mpd_song *song = mpd_entity_get_song(entity);
			q->total_duration += mpd_song_get_duration(song);
		}
	}
}

void queue_page_update(QueuePage *q, Client *client) {
	// FIXME!: sometimes queue does not get refetched!
	if (client->events & EVENT_QUEUE_CHANGED) {
		// TODO: remove or reoder only those songs that were changed.
		// Currently the entire queue is being rebuild.
		fetch_queue(q, client);
		TraceLog(LOG_INFO, "QUEUE: Updated due outside interference (%d songs)", q->entries.len);
		q->initialized = true;
	}

	if (!q->initialized) {
		fetch_queue(q, client);
		q->initialized = true;
	}
}

void draw_reordering_entry(QueuePage *q, Client *client, State *state) {
	if (q->reordering_idx < 0) return;

	QueueEntry *reordering = &q->entries.items[q->reordering_idx];

	// Move currently reordering entry to mouse position
	reordering->pos_y = GetMouseY()
		- q->reorder_click_offset_y
		- state->container.y
		+ state->scroll;

	// Reorder and draw currently reordering entry
	queue_reorder_entry(q, reordering, entry_number_from_pos(reordering));
	entry_draw(q->reordering_idx, reordering, q, client, state);

	// Scroll following
	float relative_pos_y = reordering->pos_y - state->scroll;
	float top = (relative_pos_y + 0) - 0;
	float bottom = (relative_pos_y + ENTRY_HEIGHT) - state->container.height;
	if (top < 0.0)    q->scrollable.target_scroll += top / 3.0;
	if (bottom > 0.0) q->scrollable.target_scroll += bottom / 3.0;

	// Reordering stopped
	if (!IsMouseButtonDown(MOUSE_BUTTON_LEFT)) {
		// Reorder actual queue
		// TODO: discard reoder when request has failed
		client_push_action(
			client,
			(Action){
				ACTION_REORDER_QUEUE,
				{ .reorder = {
					.from = q->reordered_from_number,
					.to = reordering->number
				} }
			}
		);

		entry_tween_to_rest(reordering);
		q->reordering_idx = -1;
	}
}

void queue_page_draw(QueuePage *q, Client *client, State *state) {
	float transition = state->page_transition;
	if (state->page == PAGE_QUEUE) {
		if (!q->is_opened) {
			q->is_opened = true;

			// Scroll to the currently playing song
			if (client->cur_status) {
				int cur_number = mpd_status_get_song_pos(client->cur_status);
				if (cur_number >= 0) {
					int scroll = cur_number * ENTRY_HEIGHT - ENTRY_HEIGHT;
					q->scrollable.target_scroll = scroll;
				}
			}
		}
	} else {
		q->is_opened = false;

		if (state->prev_page == PAGE_QUEUE) {
			if (!tween_playing(&state->page_tween)) return;
			transition = 1.0 - transition;
		} else {
			return;
		}
	}

	int sw = GetScreenWidth();
	int sh = GetScreenHeight();
	Rect container = rect(
		PADDING + sw * (1.0 - transition),
		PADDING,
		sw - PADDING*2,
		sh - PADDING*2 - (QUEUE_STATS_HEIGHT + CUR_PLAY_HEIGHT)
	);

	float all_entries_height = q->entries.len * ENTRY_HEIGHT;
	scrollable_set_height(
		&q->scrollable,
		all_entries_height + PADDING*2 - container.height
	);

	scrollable_update(&q->scrollable);

	state->scroll = q->scrollable.scroll;
	state->container = container;

	// Draw background gradient
	if (tween_playing(&state->page_tween)) {
		float offset_x = sw * (1.0 - transition * 2.0);
		DrawRectangle(offset_x + sw, 0, sw, sh, state->background);
		DrawRectangleGradientH(offset_x, 0, sw, sh, ColorAlpha(state->background, 0.0), state->background);
	}

	// Draw curly thing below all entries
	Rect curly_rect = {
		state->container.x + PADDING,
		state->container.y - state->scroll + all_entries_height,
		state->container.width - PADDING*2,
		ENTRY_HEIGHT
	};

	draw_line(state, LINE_CURLY, vec(curly_rect.x, curly_rect.y), curly_rect.width, THEME_GRAY);

	// ==============================
	// Draw entries
	// ==============================

	unsigned elapsed = mpd_status_get_elapsed_ms(client->cur_status) / (int)1000;

	for (size_t i = 0; i < q->entries.len; i++) {
		QueueEntry *entry = &q->entries.items[i];

		// TODO: it would be better to cache the total elapsed time
		if (entry->number < mpd_status_get_song_pos(client->cur_status)) {
			elapsed += mpd_song_get_duration(mpd_entity_get_song(entry->entity));
		}

		if ((int)i == q->reordering_idx) continue;

		entry_draw((int)i, entry, q, client, state);
	}

	// Draw entry that is currently being reordered
	draw_reordering_entry(q, client, state);

	// ==============================
	// Draw scroll thumb
	// ==============================

	// TODO: implement dragging the thumb to scroll
	int cont_height = (int)state->container.height;
	int scroll_height = cont_height + (int)q->scrollable.height;
	int thumb_height = MAX(cont_height * cont_height / scroll_height, 32);
	if (thumb_height < cont_height)
		DrawRectangle(
			state->container.x + state->container.width + 3,
			state->container.y + state->scroll * (cont_height - thumb_height) / (int)q->scrollable.height,
			2,
			thumb_height,
			state->foreground
		);

	// ==============================
	// Draw queue stats
	// ==============================

	Rect stats_rect = rect(
		0,
		sh - (QUEUE_STATS_HEIGHT + CUR_PLAY_HEIGHT) * transition,
		sw,
		QUEUE_STATS_HEIGHT
	);
	DrawRectangleRec(stats_rect, state->background);
	DrawRectangle(
		stats_rect.x,
		stats_rect.y,
		stats_rect.width,
		1,
		THEME_GRAY
	);

	// Draw number of tracks
	Text text = (Text){
		.text = TextFormat("♪ %d", q->entries.len),
		.font = state->normal_font,
		.size = THEME_NORMAL_TEXT_SIZE,
		.pos = {
			stats_rect.x + PADDING*2,
			stats_rect.y + QUEUE_STATS_PADDING
		},
		.color = THEME_SUBTLE_TEXT,
	};
	draw_text(text);

	// Draw queue elapsed time
	unsigned time_left = 0;
	if (elapsed <= q->total_duration)
		time_left = q->total_duration - elapsed;

	text.text = format_time(time_left, true);
	Vec dur_size = measure_text(&text);
	text.pos.x = stats_rect.x + stats_rect.width - dur_size.x - PADDING*2;
	draw_text(text);
}

void queue_page_free(QueuePage *q) {
	for (size_t i = 0; i < q->entries.len; i++) {
		entry_free(&q->entries.items[i]);
	}
	q->entries.len = 0;
	free(q->entries.items);
}
