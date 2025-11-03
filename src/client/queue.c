#include "./queue.h"
#include "../client.h"
#include "../macros.h"
#include "../utils.h"
#include "../pages/queue_page.h"

static QueueItem _queue_item_new(unsigned number, struct mpd_entity *entity) {
	assert(mpd_entity_get_type(entity) == MPD_ENTITY_TYPE_SONG);
	const struct mpd_song *song = mpd_entity_get_song(entity);

	const char *filename = path_basename(mpd_song_get_uri(song));

	QueueItem item = {
		.number = number,
		.entity = entity,
		.filename = filename,

		.pos_y = number * QUEUE_ITEM_HEIGHT,
		.prev_pos_y = number * QUEUE_ITEM_HEIGHT,
		.pos_tween = timer_new(200, false),

		.duration_str = {0},
	};

	format_time(item.duration_str, mpd_song_get_duration(song), false);

	return item;
}

static void _queue_item_free(QueueItem *i) {
	if (i->entity) {
		mpd_entity_free(i->entity);
		i->entity = NULL;
	}
}

void queue_fetch(Queue *q, struct mpd_connection *conn) {
	clock_t start = clock();

	bool res = mpd_send_list_queue_meta(conn);
	if (!res) {
		CONN_HANDLE_ERROR(conn);
		return;
	}

	// Free previous entries
	for (size_t i = 0; i < q->len; i++) {
		_queue_item_free(&q->items[i]);
	}
	q->len = 0;
	q->total_duration_sec = 0;

	DA_RESERVE(q, 512);

	// Receive queue entities/songs from the server
	while (true) {
		struct mpd_entity *entity = mpd_recv_entity(conn);
		if (entity == NULL) {
			CONN_HANDLE_ERROR(conn);
			break;
		}

		enum mpd_entity_type typ = mpd_entity_get_type(entity);
		if (typ == MPD_ENTITY_TYPE_SONG) {
			// Push the received song entity into the queue dynamic array
			size_t idx = q->len;
			DA_PUSH(q, _queue_item_new(idx, entity));

			const struct mpd_song *song = mpd_entity_get_song(entity);
			q->total_duration_sec += mpd_song_get_duration(song);
		}
	}

	clock_t end = clock();
	int time = (int)((double)(end - start) / CLOCKS_PER_SEC * 1000);

	TraceLog(LOG_INFO, "MPD CLIENT: QUEUE: Updated in %dms (%d songs)", time, q->len);
}

void queue_free(Queue *q) {
	for (size_t i = 0; i < q->len; i++) {
		_queue_item_free(&q->items[i]);
	}
	free(q->items);
	q->len = 0;
	q->cap = 0;
	q->items = NULL;
}
