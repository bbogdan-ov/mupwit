#ifndef ALBUMS_PAGE_H
#define ALBUMS_PAGE_H

#include "../context.h"
#include "../ui/scrollable.h"

typedef struct AlbumItem {
	AlbumInfo info;

	ArtworkImage artwork;
	Timer artwork_tween;
} AlbumItem;

typedef struct Albums {
	DA_FIELDS(AlbumItem)

	Scrollable scrollable;
} Albums;

Albums albums_page_new(void);

void albums_page_on_event(Albums *a, Event event);

void albums_page_draw(Albums *a, Context ctx);

void albums_page_free(Albums *a);

#endif
