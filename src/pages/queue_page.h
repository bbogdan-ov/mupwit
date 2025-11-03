#ifndef QUEUE_PAGE_H
#define QUEUE_PAGE_H

#include "../client.h"
#include "../state.h"
#include "../assets.h"
#include "../ui/draw.h"
#include "../ui/scrollable.h"
#include "../ui/tween.h"

#define QUEUE_PAGE_PADDING 8
#define QUEUE_ITEM_ARTWORK_SIZE 32
#define QUEUE_ITEM_HEIGHT (QUEUE_ITEM_ARTWORK_SIZE + QUEUE_PAGE_PADDING*2)

#define QUEUE_STATS_PADDING 4
#define QUEUE_STATS_HEIGHT (THEME_NORMAL_TEXT_SIZE + QUEUE_STATS_PADDING*2)

typedef struct QueuePage {
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

void queue_page_draw(
	QueuePage *q,
	Client *client,
	State *state,
	Assets *assets
);

#endif
