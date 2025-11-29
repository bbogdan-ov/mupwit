#ifndef ARTWORK_IMAGE_H
#define ARTWORK_IMAGE_H

#include <raylib.h>

typedef struct ArtworkImage {
	// ID of the request
	// Can be -1
	int req_id_nullable;

	Texture texture;
	// Average color of the artwork
	Color color;
	bool exists;
	bool received;
} ArtworkImage;

// NOTE: this must be included right here because of
// C preprocessing quirks (absolutely not my fault)
#include "../client.h"

ArtworkImage artwork_image_new(void);

void artwork_image_on_response_event(ArtworkImage *a, Event event);

void artwork_image_fetch(ArtworkImage *a, Client *client, const char *song_uri);
void artwork_image_cancel(ArtworkImage *a, Client *client);

bool artwork_image_is_fetching(const ArtworkImage *a);

#endif
