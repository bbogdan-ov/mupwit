#ifndef ARTWORK_IMAGE_H
#define ARTWORK_IMAGE_H

#include <raylib.h>

#include "../client.h"

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

ArtworkImage artwork_image_new(void);

void artwork_image_fetch(ArtworkImage *a, Client *client, const char *song_uri);

// Update `ArtworkImage` 60 per second
// Sets received `image`, pass NULL if you don't care
// It may set zeroed `image` which means there is no artwork
//
// Returns whether the texture was changed
bool artwork_image_update(ArtworkImage *a, Client *client, Image *image);

#endif
