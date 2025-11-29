#include <string.h>

#include "./queue_page.h"
#include "../macros.h"
#include "../theme.h"
#include "../macros.h"
#include "../ui/currently_playing.h"

#include <raymath.h>

#define GRAB_THRESHOLD 8

// TODO: draw "no songs" when queue is empty

QueuePage queue_page_new(void) {
	return (QueuePage){
		.trying_to_grab_idx = -1,
		.reordering_idx = -1,

		.scrollable = scrollable_new(),
	};
}

static void _item_tween_to_rest(QueueItem *e) {
	e->prev_pos_y = e->pos_y;
	e->pos_y = e->number * QUEUE_ITEM_HEIGHT;
	timer_play(&e->pos_tween);
}

static int _item_number_from_pos(QueueItem *e) {
	return (int)((e->pos_y + QUEUE_ITEM_HEIGHT / 2) / QUEUE_ITEM_HEIGHT);
}

static void _item_draw(
	int idx,
	QueueItem *item,
	QueuePage *queue,
	Context ctx
) {
#define IS_REORDERING (queue->reordering_idx == idx)
#define IS_TRYING_TO_GRAB (queue->trying_to_grab_idx == idx)

	Rect rect = {
		ctx.state->container.x,
		ctx.state->container.y - ctx.state->scroll + item->pos_y,
		ctx.state->container.width,
		QUEUE_ITEM_HEIGHT
	};

	// Draw only visible entries
	if (!CheckCollisionRecs(rect, screen_rect())) return;

	timer_update(&item->pos_tween);
	float pos_y = Lerp(
		item->prev_pos_y,
		item->pos_y,
		EASE_OUT_CUBIC(timer_progress(&item->pos_tween))
	);
	rect.y = ctx.state->container.y - ctx.state->scroll + pos_y;

	const struct mpd_song *song = mpd_entity_get_song(item->entity);
	unsigned song_id = mpd_song_get_id(song);

	Rect inner = rect_shrink(rect, QUEUE_PAGE_PADDING, 0);
	Color background = ctx.state->background;

	// ==============================
	// Entry events
	// ==============================

	// NOTE: status mutex is locked in the `queue_page_draw()` so it is safe to
	// use `_cur_song_nullable` directly
	bool is_playing = false;
	if (ctx.client->_cur_song_nullable) {
		is_playing = mpd_song_get_id(ctx.client->_cur_song_nullable) == song_id;
	}

	Vec mouse_pos = get_mouse_pos();
	bool is_hovering = CheckCollisionPointRec(mouse_pos, rect);
	is_hovering = is_hovering && CheckCollisionPointRec(mouse_pos, ctx.state->container);

	// Clicking on item will start "trying to grab mode"
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
			item->prev_pos_y = item->pos_y;
			timer_play(&item->pos_tween);

			queue->trying_to_grab_idx = -1;
			queue->reordering_idx = idx;
			queue->reordered_from_number = item->number;
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
		client_push_action(ctx.client, (Action){ACTION_PLAY_SONG, {.song_id = song_id}});
	}

	// ==============================
	// Draw item
	// ==============================

	// Draw background when hovering over or reordering the item
	if (
		(is_hovering && queue->reordering_idx < 0 && queue->trying_to_grab_idx < 0)
		|| IS_REORDERING
		|| IS_TRYING_TO_GRAB
	) {
		background = ctx.state->foreground;
		ctx.state->cursor = MOUSE_CURSOR_POINTING_HAND;
		draw_box(ctx.assets, BOX_FILLED_ROUNDED, rect, background);
	}

	// Show "currently playing" marker
	if (is_playing) {
		draw_icon(
			ctx.assets,
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
		inner.y + QUEUE_ITEM_HEIGHT/2 - QUEUE_ITEM_ARTWORK_SIZE/2,
		QUEUE_ITEM_ARTWORK_SIZE,
		QUEUE_ITEM_ARTWORK_SIZE
	};
	draw_icon(
		ctx.assets,
		ICON_DISK,
		vec(
			artwork_rect.x + artwork_rect.width/2 - ICON_SIZE/2,
			artwork_rect.y + artwork_rect.height/2 - ICON_SIZE/2
		),
		THEME_BLACK
	);
	draw_box(ctx.assets, BOX_NORMAL, artwork_rect, THEME_BLACK);
	inner.x += artwork_rect.width + QUEUE_PAGE_PADDING;
	inner.width -= artwork_rect.width + QUEUE_PAGE_PADDING;

	Text text = {
		.text = "",
		.font = ctx.assets->normal_font,
		.size = THEME_NORMAL_TEXT_SIZE,
		.pos = {0},
		.color = THEME_SUBTLE_TEXT,
	};

	// Draw song duration
	text.text = item->duration_str;
	Vec dur_size = measure_text(&text);
	text.pos = vec(
		inner.x + inner.width - dur_size.x,
		inner.y + QUEUE_ITEM_HEIGHT/2 - dur_size.y/2
	);
	draw_text(text);
	inner.width -= dur_size.x + QUEUE_PAGE_PADDING;

	BeginScissorMode(inner.x, inner.y, inner.width, inner.height);

	const char *title = mpd_song_get_tag(song, MPD_TAG_TITLE, 0);
	const char *artist_nullable = mpd_song_get_tag(song, MPD_TAG_ARTIST, 0);
	if (!title) {
		title = item->filename;
	}

	// Draw song title
	text.text = title;
	text.color = THEME_TEXT;
	text.pos = vec(
		inner.x,
		inner.y + QUEUE_ITEM_HEIGHT/2 - THEME_NORMAL_TEXT_SIZE
	);

	if (!artist_nullable) {
		// Center title if artist is unknown
		text.pos.y += THEME_NORMAL_TEXT_SIZE/2;
	}

	draw_cropped_text(text, inner.width, background);
	text.pos.y += THEME_NORMAL_TEXT_SIZE;

	// Draw song artist
	if (artist_nullable) {
		text.text = artist_nullable;
		text.color = THEME_SUBTLE_TEXT;
		draw_cropped_text(text, inner.width, background);
	}

	EndScissorMode();
}

// Reorder item UI element, does NOT affect the actual queue.
// Any item reordering also does NOT affect the order of items in the array (`ctx.client->_queue`)
void _page_reorder_entry(QueuePage *q, QueueItem *item, int to_number, Context ctx) {
	// NOTE: queue mutex is locked in `queue_page_draw()` so it is safe to use
	// `ctx.client->_queue` directly
	Queue *queue = &ctx.client->_queue;

	to_number = CLAMP(to_number, 0, queue->len - 1);

	int range_from = 0;
	int range_to = 0;
	int move_by = 0;

	if (to_number > item->number) {
		// Entry was moved down
		range_from = item->number;
		range_to = to_number;
		move_by = -1;
	} else if (to_number < item->number) {
		// Entry was moved up
		range_from = to_number;
		range_to = item->number;
		move_by = 1;
	}

	if (move_by == 0) return;

	// Reorder all entries inside range `range_from`-`range_to`
	for (size_t i = 0; i < queue->len; i++) {
		if ((int)i == q->reordering_idx) continue;

		QueueItem *another = &queue->items[i];

		if (another->number >= range_from && another->number <= range_to) {
			int moved_number = another->number + move_by;
			if (moved_number >= 0 && moved_number < (int)queue->len) {
				another->number = moved_number;
				_item_tween_to_rest(another);
			}
		}
	}

	item->number = to_number;
}

void queue_page_on_event(QueuePage *q, Event event) {
	if (event.kind == EVENT_QUEUE_CHANGED) {
		q->trying_to_grab_idx = -1;
		q->reordering_idx = -1;
		q->reorder_click_offset_y = 0;
	}
}

static void _page_draw_reordering_item(QueuePage *q, Context ctx) {
	if (q->reordering_idx < 0) return;

	// NOTE: queue mutex is locked in `queue_page_draw()` so it is safe to use
	// `ctx.client->_queue` directly
	QueueItem *reordering = &ctx.client->_queue.items[q->reordering_idx];

	// Move currently reordering item to mouse position
	reordering->pos_y = GetMouseY()
		- q->reorder_click_offset_y
		- ctx.state->container.y
		+ ctx.state->scroll;

	// Reorder and draw currently reordering item
	_page_reorder_entry(q, reordering, _item_number_from_pos(reordering), ctx);
	_item_draw(q->reordering_idx, reordering, q, ctx);

	// Scroll following
	float relative_pos_y = reordering->pos_y - ctx.state->scroll;
	float top = (relative_pos_y + 0) - 0;
	float bottom = (relative_pos_y + QUEUE_ITEM_HEIGHT) - ctx.state->container.height;
	if (top < 0.0)    q->scrollable.target_scroll += top / 3.0;
	if (bottom > 0.0) q->scrollable.target_scroll += bottom / 3.0;

	// Reordering stopped
	if (!IsMouseButtonDown(MOUSE_BUTTON_LEFT)) {
		// Reorder actual queue
		// TODO: discard reoder when request has failed
		client_push_action(
			ctx.client,
			(Action){
				ACTION_REORDER_QUEUE,
				{ .reorder = {
					.from = q->reordered_from_number,
					.to = reordering->number
				} }
			}
		);

		_item_tween_to_rest(reordering);
		q->reordering_idx = -1;
	}
}

void queue_page_draw(QueuePage *q, Context ctx) {
	const struct mpd_song   *cur_song_nullable;
	const struct mpd_status *cur_status_nullable;
	client_lock_status_nullable(
		ctx.client,
		&cur_song_nullable,
		&cur_status_nullable
	);

	const Queue *queue = client_lock_queue(ctx.client);

	float transition = ctx.state->page_transition;
	if (ctx.state->page == PAGE_QUEUE) {
		if (!q->is_opened) {
			q->is_opened = true;

			// Scroll to the currently playing song
			if (cur_status_nullable) {
				int cur_number = mpd_status_get_song_pos(cur_status_nullable);
				if (cur_number >= 0) {
					int scroll = cur_number * QUEUE_ITEM_HEIGHT - QUEUE_ITEM_HEIGHT;
					q->scrollable.target_scroll = scroll;
				}
			}
		}
	} else {
		q->is_opened = false;

		if (ctx.state->prev_page == PAGE_QUEUE) {
			if (!timer_playing(&ctx.state->page_tween)) goto defer;
			transition = 1.0 - transition;
		} else {
			goto defer;
		}
	}

	int sw = GetScreenWidth();
	int sh = GetScreenHeight();
	Rect container = rect(
		QUEUE_PAGE_PADDING + sw * (1.0 - transition),
		QUEUE_PAGE_PADDING,
		sw - QUEUE_PAGE_PADDING*2,
		sh - QUEUE_PAGE_PADDING*2 - (QUEUE_STATS_HEIGHT + CUR_PLAY_HEIGHT)
	);

	float all_entries_height = queue->len * QUEUE_ITEM_HEIGHT;
	scrollable_set_height(
		&q->scrollable,
		all_entries_height + QUEUE_PAGE_PADDING*2 - container.height
	);

	scrollable_update(&q->scrollable);

	ctx.state->scroll = q->scrollable.scroll;
	ctx.state->container = container;

	// Draw background gradient
	if (timer_playing(&ctx.state->page_tween)) {
		float offset_x = sw * (1.0 - transition * 2.0);
		DrawRectangle(offset_x + sw, 0, sw, sh, ctx.state->background);
		DrawRectangleGradientH(offset_x, 0, sw, sh, ColorAlpha(ctx.state->background, 0.0), ctx.state->background);
	}

	// Draw curly thing below all entries
	Rect curly_rect = {
		ctx.state->container.x + QUEUE_PAGE_PADDING,
		ctx.state->container.y - ctx.state->scroll + all_entries_height,
		ctx.state->container.width - QUEUE_PAGE_PADDING*2,
		QUEUE_ITEM_HEIGHT
	};
	draw_line(
		ctx.assets,
		LINE_CURLY,
		vec(curly_rect.x, curly_rect.y),
		curly_rect.width,
		THEME_GRAY
	);

	// Draw scroll thumb
	scrollable_draw_thumb(&q->scrollable, ctx.state, ctx.state->foreground);

	// ==============================
	// Draw entries
	// ==============================

	unsigned elapsed_sec = 0;
	if (cur_status_nullable)
		elapsed_sec = mpd_status_get_elapsed_ms(cur_status_nullable) / (int)1000;

	for (size_t i = 0; i < queue->len; i++) {
		QueueItem *item = &queue->items[i];

		// TODO: it would be better to cache the total elapsed time
		if (cur_status_nullable) {
			if (item->number < mpd_status_get_song_pos(cur_status_nullable)) {
				elapsed_sec += mpd_song_get_duration(mpd_entity_get_song(item->entity));
			}
		}

		if ((int)i == q->reordering_idx) continue;

		_item_draw((int)i, item, q, ctx);
	}

	// Draw item that is currently being reordered
	_page_draw_reordering_item(q, ctx);

	// ==============================
	// Draw queue stats
	// ==============================

	Rect stats_rect = rect(
		0,
		sh - (QUEUE_STATS_HEIGHT + CUR_PLAY_HEIGHT) * transition,
		sw,
		QUEUE_STATS_HEIGHT
	);
	DrawRectangleRec(stats_rect, ctx.state->background);
	DrawRectangle(
		stats_rect.x,
		stats_rect.y,
		stats_rect.width,
		1,
		THEME_GRAY
	);

	static char count_str[26] = {0};
	snprintf(count_str, 25, "♪ %ld", queue->len);
	count_str[25] = 0;

	// Draw number of tracks
	Text text = (Text){
		.text = count_str,
		.font = ctx.assets->normal_font,
		.size = THEME_NORMAL_TEXT_SIZE,
		.pos = {
			stats_rect.x + QUEUE_PAGE_PADDING*2,
			stats_rect.y + QUEUE_STATS_PADDING
		},
		.color = THEME_SUBTLE_TEXT,
	};
	draw_text(text);

	// Draw queue elapsed time
	unsigned time_left = 0;
	if (elapsed_sec <= queue->total_duration_sec)
		time_left = queue->total_duration_sec - elapsed_sec;

	static char time_left_str[TIME_BUF_LEN] = {0};
	format_time(time_left_str, time_left, true);

	text.text = time_left_str;
	Vec dur_size = measure_text(&text);
	text.pos.x = stats_rect.x + stats_rect.width - dur_size.x - QUEUE_PAGE_PADDING*2;
	draw_text(text);

defer:
	client_unlock_status(ctx.client);
	client_unlock_queue(ctx.client);
}
