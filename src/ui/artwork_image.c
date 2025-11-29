#include "./artwork_image.h"
#include "../macros.h"

ArtworkImage artwork_image_new(void) {
	return (ArtworkImage){
		.req_id_nullable = -1,
		.texture = (Texture){0},
		.color = (Color){0},
		.exists = false,
		.received = false,
	};
}

static void _artwork_image_update(ArtworkImage *a, Image image, Color color) {
	if (image.data) {
		update_texture_from_image(&a->texture, image);
		a->color = color;
		a->exists = true;
	} else {
		a->exists = false;
	}
}

void artwork_image_on_response_event(ArtworkImage *a, Event event) {
	if (a->req_id_nullable <= 0 || a->received) return;

	assert(event.kind == EVENT_RESPONSE);
	assert(event.data.response_artwork.id > 0);
	assert(event.data.response_artwork.image.data != NULL);

	if (a->req_id_nullable != event.data.response_artwork.id) return;

	_artwork_image_update(
		a,
		event.data.response_artwork.image,
		event.data.response_artwork.color
	);

	a->received = true;
	a->req_id_nullable = -1;
}

void artwork_image_fetch(ArtworkImage *a, Client *client, const char *song_uri) {
	artwork_image_cancel(a, client);

	int id = client_request(client, song_uri);
	a->req_id_nullable = id;
	if (id <= 0) return;

	a->received = false;
}

void artwork_image_cancel(ArtworkImage *a, Client *client) {
	if (a->req_id_nullable > 0) {
		client_cancel_request(client, a->req_id_nullable);
		a->req_id_nullable = -1;
	}
}

bool artwork_image_is_fetching(const ArtworkImage *a) {
	return a->req_id_nullable > 0;
}
