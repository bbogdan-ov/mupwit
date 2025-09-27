#ifndef QUEUE_PAGE_H
#define QUEUE_PAGE_H

#include "../client.h"
#include "../state.h"
#include "../ui/scrollable.h"
#include "../ui/tween.h"

typedef struct QueueEntry {
	// Position of the entry in the queue (0-based)
	int number;
	bool deleted;

	// Current drawing position of the entry UI element
	float pos_y;
	// Previous drawing position of the entry UI element assigned before
	// playing `pos_tween`.
	// Used to smoothly interpolate between this value and `target_pos_y`.
	float prev_pos_y;
	Tween tween;

	// MPD queue entity/song
	// Type is guaranteed to be MPD_ENTITY_TYPE_SONG
	struct mpd_entity *entity;
	// Prerendered song duration in human-readable format
	char *duration_text;
} QueueEntry;

typedef struct QueueEntriesList {
	QueueEntry *items;
	size_t len;
	size_t cap;
} QueueEntriesList;

typedef struct QueuePage {
	// Array of song UI elements in the current queue
	QueueEntriesList entries;
	// Number of entries with `deleted` flag set to true
	size_t deleted_count;
	// Number of entries that are ready to be deleted from the `entries` array
	size_t scheduled_deletion_count;

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

QueuePage queue_page_new();

void queue_page_update(QueuePage *q, Client *client);
void queue_page_draw(QueuePage *q, Client *client, State *state);

// Returns number of "existing" entries (entries with `deleted` flag set to false)
size_t queue_page_entries_count(QueuePage *q);

void queue_page_free(QueuePage *q);

#endif
