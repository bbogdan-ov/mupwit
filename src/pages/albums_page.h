#ifndef ALBUMS_PAGE_H
#define ALBUMS_PAGE_H

#include "../client.h"
#include "../state.h"
#include "../assets.h"
#include "../ui/scrollable.h"

typedef struct AlbumsPage {
	Scrollable scrollable;
} AlbumsPage;

AlbumsPage albums_page_new(void);

void albums_page_draw(AlbumsPage *a, Client *client, State *state, Assets *assets);

#endif
