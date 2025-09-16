#ifndef QUEUE_PAGE_H
#define QUEUE_PAGE_H

#include "../client.h"
#include "../state.h"
#include "../ui/scrollable.h"

typedef struct QueuePage {
	Scrollable scrollable;
} QueuePage;

QueuePage queue_page_new();

void queue_page_draw(QueuePage *q, Client *client, State *state);

#endif
