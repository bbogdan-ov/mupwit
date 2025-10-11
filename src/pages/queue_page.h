#ifndef QUEUE_PAGE_H
#define QUEUE_PAGE_H

#include "../client.h"
#include "../state.h"
#include "../ui/draw.h"
#include "../ui/scrollable.h"
#include "../ui/tween.h"

#define QUEUE_STATS_PADDING 4
#define QUEUE_STATS_HEIGHT THEME_NORMAL_TEXT_SIZE

typedef struct QueueEntry {
	// Position of the entry in the queue (0-based)
	int number;

	// Current drawing position of the entry UI element
	float pos_y;
	// Previous drawing position of the entry UI element assigned before
	// playing `pos_tween`.
	// Used to smoothly interpolate between this value and `target_pos_y`.
	float prev_pos_y;
	Tween pos_tween;

	// MPD queue entity/song
	// Type is guaranteed to be MPD_ENTITY_TYPE_SONG
	struct mpd_entity *entity;
	// Prerendered song duration in human-readable format
	char duration_text[TIME_BUF_LEN];
} QueueEntry;

typedef struct QueueEntriesList {
	QueueEntry *items;
	size_t len;
	size_t cap;
} QueueEntriesList;

typedef struct QueuePage {
	// Array of song UI elements in the current queue
	QueueEntriesList entries;

	unsigned total_duration;

	int trying_to_grab_idx;
	// Currently reordering entry index
	// -1 - nothing is being dragged
	int reordering_idx;
	// Number of the reordered entry from which it was reordered
	int reordered_from_number;
	float reorder_click_offset_y;

	bool is_opened;

	Scrollable scrollable;
} QueuePage;

QueuePage queue_page_new(void);

void queue_page_update(QueuePage *q, Client *client);

void queue_page_draw(QueuePage *q, Client *client, State *state);

void queue_page_free(QueuePage *q);

#endif
