#ifndef QUEUE_PAGE_H
#define QUEUE_PAGE_H

#include "../client.h"
#include "../state.h"
#include "../ui/scrollable.h"

typedef struct QueueEntry {
	float pos_y;
	bool dragging;

	const struct mpd_song *song;
	char *duration_text;
} QueueEntry;

typedef struct QueueEntriesList {
	QueueEntry *items;
	size_t len;
	size_t cap;
} QueueEntriesList;

typedef struct QueuePage {
	QueueEntriesList entries;

	Scrollable scrollable;
} QueuePage;

QueuePage queue_page_new();

void queue_page_update(QueuePage *q, Client *client);

void queue_page_draw(QueuePage *q, Client *client, State *state);

#endif
