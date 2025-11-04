#ifndef ALBUMS_PAGE_H
#define ALBUMS_PAGE_H

#include "../context.h"
#include "../ui/scrollable.h"

typedef struct AlbumsPage {
	Scrollable scrollable;
} AlbumsPage;

AlbumsPage albums_page_new(void);

void albums_page_draw(AlbumsPage *a, Context ctx);

#endif
