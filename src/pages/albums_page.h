#ifndef ALBUMS_PAGE_H
#define ALBUMS_PAGE_H

#include "../client.h"
#include "../state.h"
#include "../ui/scrollable.h"

typedef struct AlbumEntry {
	char *title;
	char *artist_nullable;
	char *first_song_uri_nullable;

	Tween artwork_tween;
	Texture artwork_texture_nullable;
	bool artwork_texture_loaded;

	pthread_mutex_t artwork_mutex;
	Image artwork_image_nullable;
	bool artwork_is_ready;
	bool waiting_for_artwork;
} AlbumEntry;

typedef struct AlbumEntriesList {
	AlbumEntry *items;
	size_t len;
	size_t cap;
} AlbumEntriesList;

typedef struct AlbumsPage {
	AlbumEntriesList entries;

	Scrollable scrollable;
} AlbumsPage;

AlbumsPage albums_page_new(void);

void albums_page_update(AlbumsPage *a, Client *client);

void albums_page_draw(AlbumsPage *a, Client *client, State *state);

void albums_page_free(AlbumsPage *a);

#endif
