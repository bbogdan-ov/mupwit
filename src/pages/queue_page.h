#ifndef QUEUE_PAGE_H
#define QUEUE_PAGE_H

#include "../context.h"
#include "../ui/draw.h"
#include "../ui/scrollable.h"

#define QUEUE_PAGE_PADDING 8
#define QUEUE_ITEM_ARTWORK_SIZE 32
#define QUEUE_ITEM_HEIGHT (QUEUE_ITEM_ARTWORK_SIZE + QUEUE_PAGE_PADDING*2)

#define QUEUE_STATS_PADDING 4
#define QUEUE_STATS_HEIGHT (THEME_NORMAL_TEXT_SIZE + QUEUE_STATS_PADDING*2)

typedef struct QueueItem {
	// MPD queue entity/song
	// Type is guaranteed to be `MPD_ENTITY_TYPE_SONG`
	struct mpd_entity *entity;
	const char *filename;

	// Position of the entry in the queue (0-based)
	int number;
	// Current drawing position
	float pos_y;
	// Previous drawing position assigned before playing `pos_tween`.
	// Used to smoothly interpolate between this value and `pos_y`.
	float prev_pos_y;
	Timer pos_tween;

	// Prerendered song duration in human-readable format
	char duration_str[TIME_BUF_LEN];
} QueueItem;

typedef struct Queue {
	DA_FIELDS(QueueItem)

	unsigned total_duration_sec;

	int trying_to_grab_idx;
	// Currently reordering entry index
	// -1 - nothing is being dragged
	int reordering_idx;
	// Number of the reordered entry from which it was reordered
	int reordered_from_number;
	float reorder_click_offset_y;

	bool is_opened;

	Scrollable scrollable;
} Queue;

Queue queue_page_new(void);

void queue_page_on_event(Queue *q, Event event);

void queue_page_draw(Queue *q, Context ctx);

void queue_page_free(Queue *q);

#endif
