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

void artwork_image_fetch(ArtworkImage *a, Client *client, const char *song_uri) {
	if (a->req_id_nullable > 0)
		client_cancel_request(client, a->req_id_nullable);

	int id = client_request(client, song_uri);
	a->req_id_nullable = id;
	if (id <= 0) return;

	a->received = false;
}

bool artwork_image_update(ArtworkImage *a, Client *client, Image *image) {
	if (a->req_id_nullable <= 0 || a->received) return false;

	if ((client->events & EVENT_RESPONSE) == 0)
		return false;

	Image img;
	Color color;
	bool received = client_request_get_artwork(client, a->req_id_nullable, &img, &color);
	if (!received) return false;

	if (img.data) {
		update_texture_from_image(&a->texture, img);
		a->exists = true;
		a->color = color;
	} else {
		a->exists = false;
	}

	if (image) *image = img;
	else       UnloadImage(img);

	a->received = true;
	return true;
}
