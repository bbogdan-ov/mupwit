#ifndef ALBUMS_H
#define ALBUMS_H

#include <mpd/client.h>

typedef struct AlbumItem {
	// These 3 are owned strings
	char *title;
	char *artist_nullable;
	char *first_song_uri_nullable;
} AlbumItem;

typedef struct Albums {
	AlbumItem *items;
	size_t len;
	size_t cap;
} Albums;

void albums_fetch(Albums *a, struct mpd_connection *conn);
void albums_free(Albums *a);

#endif
