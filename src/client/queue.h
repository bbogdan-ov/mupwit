#ifndef QUEUE_H
#define QUEUE_H

#include <mpd/client.h>

#include "../ui/draw.h"
#include "../ui/tween.h"

typedef struct QueueItem {
	// Position of the entry in the queue (0-based)
	int number;
	// MPD queue entity/song
	// Type is guaranteed to be `MPD_ENTITY_TYPE_SONG`
	struct mpd_entity *entity;
	const char *filename;

	// ==============================
	// UI related stuff
	// ==============================

	// Current drawing position
	float pos_y;
	// Previous drawing position assigned before playing `pos_tween`.
	// Used to smoothly interpolate between this value and `pos_y`.
	float prev_pos_y;
	Tween pos_tween;

	// Prerendered song duration in human-readable format
	char duration_str[TIME_BUF_LEN];
} QueueItem;

typedef struct Queue {
	QueueItem *items;
	size_t len;
	size_t cap;

	unsigned total_duration_sec;
} Queue;

void queue_fetch(Queue *q, struct mpd_connection *conn);
void queue_free(Queue *q);

#endif
