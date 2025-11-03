#define _XOPEN_SOURCE 500
#include <stdlib.h>
#include <string.h>

#include "./albums.h"
#include "../client.h"
#include "../macros.h"

static void _album_item_free(AlbumItem *item) {
	free(item->title);
	free(item->artist_nullable);
	free(item->first_song_uri_nullable);
}
static void _albums_free_all_items(Albums *a) {
	for (size_t i = 0; i < a->len; i ++) {
		_album_item_free(&a->items[i]);
	}
	a->len = 0;
}

static int _items_sort_func(const void* a, const void* b) {
	const AlbumItem *ai = a;
	const AlbumItem *bi = b;
	return strcmp(ai->title, bi->title);
}
void albums_fetch(Albums *a, struct mpd_connection *conn) {
	if (false
		|| !mpd_search_db_tags(conn, MPD_TAG_ALBUM)
		|| !mpd_search_add_group_tag(conn, MPD_TAG_ARTIST)
		|| !mpd_search_commit(conn)
	) {
		CONN_HANDLE_ERROR(conn);
		return;
	}

	// Free previous items
	_albums_free_all_items(a);
	DA_RESERVE(a, 64);

	// Collect all albums and their artists
	char *cur_artist = NULL;
	while (true) {
		struct mpd_pair *pair = mpd_recv_pair(conn);
		if (!pair) break;

		if (strcmp(pair->name, "Artist") == 0) {
			free(cur_artist);
			cur_artist = strdup(pair->value);
		}

		if (strcmp(pair->name, "Album") == 0 && strlen(pair->value) > 0) {
			AlbumItem item = {
				.title = strdup(pair->value),
				.artist_nullable = cur_artist ? strdup(cur_artist) : NULL,
				.first_song_uri_nullable = NULL,
			};
			DA_PUSH(a, item);
		}

		mpd_return_pair(conn, pair);
	}
	free(cur_artist);

	qsort(a->items, a->len, sizeof(a->items[0]), _items_sort_func);

	if (!mpd_response_finish(conn)) {
		CONN_HANDLE_ERROR(conn);
		return;
	}

	// ==============================
	// Fetch first song of each album
	// ==============================
	for (size_t i = 0; i < a->len; i++) {
		AlbumItem *item = &a->items[i];

		if (false
			|| !mpd_search_db_songs(conn, true)
			|| !mpd_search_add_tag_constraint(conn, MPD_OPERATOR_DEFAULT, MPD_TAG_ALBUM, item->title)
			|| !mpd_search_add_window(conn, 0, 1)
			|| !mpd_search_commit(conn)
		) {
			CONN_HANDLE_ERROR(conn);
			continue;
		}

		// Receive info for the first song in the album
		{
			struct mpd_pair *pair = mpd_recv_pair_named(conn, "file");
			if (!pair) continue;

			item->first_song_uri_nullable = strdup(pair->value);

			mpd_return_pair(conn, pair);
		}

		if (!mpd_response_finish(conn))
			CONN_HANDLE_ERROR(conn);
	}
}

void albums_free(Albums *a) {
	_albums_free_all_items(a);
	free(a->items);
	a->cap = 0;
	a->items = NULL;
}
