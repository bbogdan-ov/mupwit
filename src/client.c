#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include <string.h>
#include <mpd/client.h>
#include <mpd/async.h>

#include "client.h"
#include "macros.h"

const char *UNKNOWN = "<unknown>";

Client client_new(void) {
	pthread_mutex_t mutex;
	pthread_mutex_init(&mutex, NULL);

	pthread_mutex_t conn_state_mutex;
	pthread_mutex_init(&conn_state_mutex, NULL);

	size_t queue_cap = 512; // 512 songs
	size_t queue_len = 0;
	struct mpd_entity **queue = malloc(queue_cap * sizeof(const struct mpd_entity*));

	return (Client){
		.cur_song = NULL,
		.cur_status = NULL,

		.queue = queue,
		.queue_len = queue_len,
		.queue_cap = queue_cap,

		.update_timer_ms = 0,

		.artwork_image = (Image){0},
		.has_artwork_image = false,

		.mutex = mutex,
		.conn_state_mutex = conn_state_mutex,
		.conn_state = CLIENT_CONN_STATE_CONNECTING,
		.conn = NULL,
	};
}

// Logs an libmpdclient error if any has occured and returns `true`,
// otherwise `false`
bool handle_error(struct mpd_connection *conn, int line) {
	enum mpd_error err = mpd_connection_get_error(conn);
	if (err != MPD_ERROR_SUCCESS) {
		const char *msg = mpd_connection_get_error_message(conn);
		TraceLog(LOG_ERROR, "MPD CLIENT (line %d): %s (%d)", line, msg, err);
		return true;
	}
	return false;
}

#define HANDLE_ERROR(CONN) handle_error(CONN, __LINE__)

// Read song album artwork into the specified buffer
// Returns size of the read buffer (0 - no artwork, -1 - error)
static int readpicture(
	Client *c,
	char **buffer,
	size_t capacity,
	char (*filetype)[16],
	const char *song_uri
) {
	size_t size = 0;

	while (true) {
		bool res = mpd_send_readpicture(c->conn, song_uri, size);
		if (!res) {
			HANDLE_ERROR(c->conn);
			return -1;
		}

		// Receive file type
		struct mpd_pair *pair = mpd_recv_pair_named(c->conn, "type");
		if (pair != NULL) {
			memcpy(*filetype, pair->value, 15); // 16 - 1 (null-terminator)
			mpd_return_pair(c->conn, pair);
		}

		// Receive current binary chunk size
		pair = mpd_recv_pair_named(c->conn, "binary");
		if (pair == NULL) {
			// Clear the previous error because `recv_pair` will set an error
			// if there is no more fields
			assert(mpd_connection_clear_error(c->conn));
			return 0; // no binary field => no artwork
		}
		const size_t chunk_size = strtoull(pair->value, NULL, 10);
		mpd_return_pair(c->conn, pair);

		// Reallocate buffer if not enough memory
		if (size + chunk_size >= capacity) {
			capacity = (size + chunk_size) * 2;
			*buffer = realloc(*buffer, capacity);
		}

		if (!mpd_recv_binary(c->conn, *buffer + size, chunk_size)) {
			TraceLog(LOG_ERROR, "MPD CLIENT: READING PICTURE (line %d): No binary data was provided in the response!", __LINE__);
			return -1;
		}

		if (!mpd_response_finish(c->conn)) {
			TraceLog(LOG_ERROR, "MPD CLIENT: READING PICTURE (line %d): Unable to finish the response!", __LINE__);
			return -1;
		}

		// End of artwork file
		if (chunk_size == 0) break;

		size += chunk_size;
	}

	return size;
}
// Fetch album artwork of the currently playing song
// Returns whether texture data was successfully updated
// Does nothing and returns `false` if there is no current song
void *do_fetch_cur_artwork(void *client) {
	Client *c = (Client*)client;

	LOCK(&c->mutex);
	assert(c->conn);

	c->has_artwork_image = false;

	if (c->cur_song == NULL) {
		UNLOCK(&c->mutex);
		return NULL;
	}

	size_t capacity = 1024 * 256; // 256KB
	char *buffer = malloc(capacity);
	char filetype[16] = {0};
	int size = readpicture(
		c,
		&buffer,
		capacity,
		&filetype,
		mpd_song_get_uri(c->cur_song)
	);

	// Simply return if there is an error or no artwork
	if (size <= 0) {
		c->artwork_image_changed = true;
		goto defer;
	}

	const char *img_filetype;
	if (strcmp(filetype, "image/png") == 0) {
		img_filetype = ".png";
	} else if (strcmp(filetype, "image/jpeg") == 0) {
		img_filetype = ".jpg";
	} else if (strcmp(filetype, "image/webp") == 0) {
		img_filetype = ".webp";
	} else if (strcmp(filetype, "image/bmp") == 0) {
		img_filetype = ".bmp";
	} else if (strcmp(filetype, "image/gif") == 0) {
		img_filetype = ".gif";
	} else {
		goto defer;
	}

	// Unload previous CPU image
	if (c->has_artwork_image)
		UnloadImage(c->artwork_image);

	// FIXME: Is `LoadImageFromMemory` thread-safe?
	Image img = LoadImageFromMemory(img_filetype, (unsigned char*)buffer, size);
	c->artwork_image = img;
	c->has_artwork_image = true;
	c->artwork_image_changed = true;

	int comps = 0;
	if (img.format == PIXELFORMAT_UNCOMPRESSED_R8G8B8)
		comps = 3;
	else if (img.format == PIXELFORMAT_UNCOMPRESSED_R8G8B8A8)
		comps = 4;

	// Calculating the average color of the artwork
	if (comps > 0) {
		unsigned char *data = img.data;
		int r, g, b;
		r = g = b = 0;
		int n = 0;
		for (int i = 0; i < img.width * img.height * comps; i += comps) {
			r += data[i + 0];
			g += data[i + 1];
			b += data[i + 2];

			n++;
		}
		r /= n;
		g /= n;
		b /= n;

		c->artwork_average_color = (Color){r, g, b, 255};
	} else {
		c->artwork_average_color = (Color){0};
	}
 
defer:
	free(buffer);
	UNLOCK(&c->mutex);
	return NULL;
}

void set_cur_status(Client *c, struct mpd_status *status) {
	if (c->cur_status) mpd_status_free(c->cur_status);
	c->cur_status = status;
}
void set_cur_song(Client *c, struct mpd_song *song) {
	if (c->cur_song) mpd_song_free(c->cur_song);
	c->cur_song = song;
}
void clear_cur_status(Client *c) {
	if (c->cur_status) {
		mpd_status_free(c->cur_status);
		c->cur_status = NULL;
	}
}
void clear_cur_song(Client *c) {
	if (c->cur_song) {
		mpd_song_free(c->cur_song);
		c->cur_song = NULL;
	}
}

void fetch_queue(Client *c) {
	assert(c->conn);

	// TODO: fetch the queue when 'playlist' idle is received
	if (c->queue_len > 0) return;

	bool res = mpd_send_list_queue_meta(c->conn);
	if (!res) {
		HANDLE_ERROR(c->conn);
		return;
	}

	while (true) {
		struct mpd_entity *entity = mpd_recv_entity(c->conn);
		if (entity == NULL) {
			HANDLE_ERROR(c->conn);
			break;
		}

		enum mpd_entity_type typ = mpd_entity_get_type(entity);
		if (typ == MPD_ENTITY_TYPE_SONG) {
			// Push the received song entity into the queue dynamic array
			if (c->queue_len + 1 >= c->queue_cap) {
				c->queue_cap = (c->queue_len + 1) * 2;
				c->queue = realloc(c->queue, c->queue_cap * sizeof(struct mpd_entity*));
			}
			c->queue[c->queue_len] = entity;
			c->queue_len += 1;
		}
	}
}

void fetch_status(Client *c) {
	assert(c->conn);

	struct mpd_status *status = mpd_run_status(c->conn);
	if (status == NULL) {
		clear_cur_status(c);
		clear_cur_song(c);
		c->artwork_image_changed = true;
		c->has_artwork_image = false;
		HANDLE_ERROR(c->conn);
		return;
	}

	// FIXME!: clear previously current status and song later or somewhere else.
	// `set_cur_status` frees the previously current status (as well as
	// `set_cur_song`) but the new status may be received only after a few
	// frames after the free so in these few frames `cur_status` and `cur_song`
	// may contain garbage
	set_cur_status(c, status);

	int cur_song_id = mpd_status_get_song_id(status);
	bool changed = !c->cur_song || (int)mpd_song_get_id(c->cur_song) != cur_song_id;
	if (changed) {
		clear_cur_song(c);

		// Set new current song
		if (cur_song_id >= 0) {
			struct mpd_song *song = mpd_run_get_queue_song_id(c->conn, cur_song_id);
			if (song) {
				set_cur_song(c, song);

				// Update current song artwork in the separate thread
				pthread_t thread;
				pthread_create(&thread, NULL, do_fetch_cur_artwork, c);

				return;
			}
		}

		c->artwork_image_changed = true;
		c->has_artwork_image = false;
		HANDLE_ERROR(c->conn);
	}
}

void *do_connect(void *client) {
	TraceLog(LOG_INFO, "MPD CLIENT: CONNECTION: Connecting to a MPD server...");

	// TODO: allow users to pass custom host and port via cli args
	struct mpd_connection *conn = mpd_connection_new(NULL, 0, 0);

	// Check for errors
	if (conn == NULL) {
		TraceLog(LOG_ERROR, "MPD CLIENT: CONNECTION: Out of memory!");
		exit(1);
	}

	Client *c = (Client*)client;
	LOCK(&c->mutex);
	LOCK(&c->conn_state_mutex);

	if (HANDLE_ERROR(conn)) {
		mpd_connection_free(conn);

		// TODO: set error message somewhere
		c->conn_state = CLIENT_CONN_STATE_ERROR;
		goto defer;
	}

	TraceLog(LOG_INFO, "MPD CLIENT: CONNECTION: Successfully connected to a MPD server");

	c->conn = conn;
	c->conn_state = CLIENT_CONN_STATE_READY;

defer:
	UNLOCK(&c->mutex);
	UNLOCK(&c->conn_state_mutex);
	return NULL;
}
void client_connect(Client *c) {
	assert(c->conn == NULL && c->conn_state == CLIENT_CONN_STATE_CONNECTING);

	pthread_t thread;
	pthread_create(&thread, NULL, do_connect, c);
}

void client_update(Client *c, Player *player, State *state) {
	if (TRYLOCK(&c->mutex) != 0) return;
	if (TRYLOCK(&c->conn_state_mutex) != 0) {
		UNLOCK(&c->mutex);
		return;
	}

	if (c->conn_state != CLIENT_CONN_STATE_READY) {
		UNLOCK(&c->mutex);
		UNLOCK(&c->conn_state_mutex);
		return;
	}
	UNLOCK(&c->conn_state_mutex);

	c->update_timer_ms -= (int)(GetFrameTime() * 1000);

	if (c->update_timer_ms <= 0) {
		fetch_status(c);
		fetch_queue(c);

		if (c->artwork_image_changed) {
			if (c->has_artwork_image)
				state_set_artwork(state, c->artwork_image, c->artwork_average_color);
			else
				state_clear_artwork(state);

			c->artwork_image_changed = false;
		}

		player_set_status(player, c->cur_status, c->cur_song);

		c->update_timer_ms = CLIENT_UPDATE_EVERY_MS;
	}

	UNLOCK(&c->mutex);
	return;
}

const char *song_tag_or_unknown(const struct mpd_song *song, enum mpd_tag_type tag) {
	const char *t = mpd_song_get_tag(song, tag, 0);
	return t == NULL ? UNKNOWN : t;
}

void client_run_seek(Client *c, int seconds) {
	if (TRYLOCK(&c->mutex) != 0) return;
	if (mpd_run_seek_current(c->conn, seconds, false))
		fetch_status(c);
	else
		HANDLE_ERROR(c->conn);
	UNLOCK(&c->mutex);
}
void client_run_toggle(Client *c) {
	if (TRYLOCK(&c->mutex) != 0) return;
	bool res = mpd_send_command(c->conn, "pause", NULL);
	res = res && mpd_response_finish(c->conn);
	if (res) fetch_status(c);
	else HANDLE_ERROR(c->conn);
	UNLOCK(&c->mutex);
}
void client_run_next(Client *c) {
	if (TRYLOCK(&c->mutex) != 0) return;
	if (mpd_run_next(c->conn))
		fetch_status(c);
	else
		HANDLE_ERROR(c->conn);
	UNLOCK(&c->mutex);
}
void client_run_prev(Client *c) {
	if (TRYLOCK(&c->mutex) != 0) return;
	if (mpd_run_previous(c->conn))
		fetch_status(c);
	else
		HANDLE_ERROR(c->conn);
	UNLOCK(&c->mutex);
}

void client_free(Client *c) {
	if (c->conn) mpd_connection_free(c->conn);
	if (c->cur_song) mpd_song_free(c->cur_song);
	if (c->cur_status) mpd_status_free(c->cur_status);

	for (size_t i = 0; i < c->queue_len; i++) {
		mpd_entity_free(c->queue[i]);
	}
	c->queue_len = 0;
}
