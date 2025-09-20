#define _GNU_SOURCE

#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include <string.h>
#include <mpd/client.h>
#include <mpd/async.h>

#include "client.h"
#include "macros.h"

const char *UNKNOWN = "<unknown>";

bool conn_handle_error(struct mpd_connection *conn, int line) {
	enum mpd_error err = mpd_connection_get_error(conn);
	if (err != MPD_ERROR_SUCCESS) {
		const char *msg = mpd_connection_get_error_message(conn);
		TraceLog(LOG_ERROR, "MPD CLIENT (line %d): %s (%d)", line, msg, err);
		return true;
	}
	return false;
}

Client client_new(void) {
	pthread_mutex_t status_mutex;
	pthread_mutex_init(&status_mutex, NULL);

	pthread_mutex_t artwork_mutex;
	pthread_mutex_init(&artwork_mutex, NULL);

	pthread_mutex_t conn_mutex;
	pthread_mutex_init(&conn_mutex, NULL);

	return (Client){
		.status_mutex = status_mutex,
		.artwork_mutex = artwork_mutex,
		.conn_mutex = conn_mutex,
	};
}

// Read song album artwork into the specified buffer
// Returns size of the read buffer (0 - no artwork, -1 - error)
static int readpicture(
	Client *c,
	char **buffer,
	size_t capacity,
	char (*filetype)[16],
	const char *song_uri
) {
	LOCK(&c->conn_mutex);

	size_t size = 0;

	while (true) {
		bool res = mpd_send_readpicture(c->conn, song_uri, size);
		if (!res) {
			CONN_HANDLE_ERROR(c->conn);
			goto error;
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
			goto no_artwork; // no binary field => no artwork
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
			goto error;
		}

		if (!mpd_response_finish(c->conn)) {
			TraceLog(LOG_ERROR, "MPD CLIENT: READING PICTURE (line %d): Unable to finish the response!", __LINE__);
			goto error;
		}

		// End of artwork file
		if (chunk_size == 0) break;

		size += chunk_size;
	}

	UNLOCK(&c->conn_mutex);
	return size;

error:
	UNLOCK(&c->conn_mutex);
	return -1;

no_artwork:
	UNLOCK(&c->conn_mutex);
	return 0;
}
// Fetch album artwork of the currently playing song
// Returns whether texture data was successfully updated
// Does nothing and returns `false` if there is no current song
void *do_fetch_cur_artwork(void *client) {
	Client *c = (Client*)client;

	LOCK(&c->status_mutex);

	if (c->cur_song == NULL) {
		UNLOCK(&c->status_mutex);
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

	UNLOCK(&c->status_mutex);
	LOCK(&c->artwork_mutex);

	// Simply return if there is an error or no artwork
	if (size <= 0) {
		c->artwork_just_changed = true;
		c->artwork_exists = false;
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
		c->artwork_just_changed = true;
		c->artwork_exists = false;
		goto defer;
	}

	// FIXME: Is `LoadImageFromMemory` thread-safe?
	Image img = LoadImageFromMemory(img_filetype, (unsigned char*)buffer, size);
	c->artwork_image = img;
	c->artwork_exists = true;
	c->artwork_just_changed = true;

	int comps = 0;
	if (img.format == PIXELFORMAT_UNCOMPRESSED_R8G8B8)
		comps = 3;
	else if (img.format == PIXELFORMAT_UNCOMPRESSED_R8G8B8A8)
		comps = 4;

	// Calculate average color of the artwork
	if (comps > 0) {
		unsigned char *data = img.data;
		int r = 0, g = 0, b = 0;
		for (int i = 0; i < img.width * img.height * comps; i += comps) {
			r += data[i + 0];
			g += data[i + 1];
			b += data[i + 2];
		}

		int n = img.width * img.height;
		c->artwork_average_color = (Color){r/n, g/n, b/n, 255};
	} else {
		c->artwork_average_color = (Color){0};
	}
 
defer:
	free(buffer);
	UNLOCK(&c->artwork_mutex);
	return NULL;
}

void free_cur_status(Client *c) {
	if (c->cur_status) {
		mpd_status_free(c->cur_status);
		c->cur_status = NULL;
	}
}
void free_cur_song(Client *c) {
	if (c->cur_song) {
		mpd_song_free(c->cur_song);
		c->cur_song_filename = NULL;
		c->cur_song = NULL;
	}
}
void set_cur_status(Client *c, struct mpd_status *status) {
	free_cur_status(c);
	c->cur_status = status;
}
void set_cur_song(Client *c, struct mpd_song *song) {
	free_cur_song(c);
	c->cur_song = song;

	// Update song filename
	if (song) {
		const char *uri = mpd_song_get_uri(song);
		const char *filename = NULL;
		if (uri) {
			filename = (const char*)memrchr(uri, '/', strlen(uri)) + 1;
			if (filename == NULL) filename = uri;
		}
		c->cur_song_filename = filename;
	} else {
		c->cur_song_filename = NULL;
	}
}

void fetch_status(Client *c) {
	if (TRYLOCK(&c->conn_mutex) != 0) return;
	if (TRYLOCK(&c->status_mutex) != 0) {
		UNLOCK(&c->conn_mutex);
		return;
	}

	struct mpd_status *status = mpd_run_status(c->conn);
	if (status == NULL) {
		free_cur_status(c);
		free_cur_song(c);

		if (TRYLOCK(&c->artwork_mutex) == 0) {
			c->artwork_just_changed = true;
			c->artwork_exists = false;
			UNLOCK(&c->artwork_mutex);
		}

		CONN_HANDLE_ERROR(c->conn);
		goto defer;
	}

	set_cur_status(c, status);

	int cur_song_id = mpd_status_get_song_id(status);
	bool changed = !c->cur_song || (int)mpd_song_get_id(c->cur_song) != cur_song_id;
	if (changed) {
		// Set new current song
		if (cur_song_id >= 0) {
			struct mpd_song *song = mpd_run_get_queue_song_id(c->conn, cur_song_id);
			if (song) {
				set_cur_song(c, song);

				// Update current song artwork in a separate thread
				pthread_t thread;
				pthread_create(&thread, NULL, do_fetch_cur_artwork, c);

				goto defer;
			}
		}

		// No current song
		free_cur_song(c);

		if (TRYLOCK(&c->artwork_mutex) == 0) {
			c->artwork_just_changed = true;
			c->artwork_exists = false;
			UNLOCK(&c->artwork_mutex);
		}

		CONN_HANDLE_ERROR(c->conn);
	}

defer:
	UNLOCK(&c->status_mutex);
	UNLOCK(&c->conn_mutex);
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

	if (CONN_HANDLE_ERROR(conn)) {
		mpd_connection_free(conn);

		// TODO: set error message somewhere
		LOCK(&c->conn_mutex);
		c->conn_state = CLIENT_CONN_STATE_ERROR;
		UNLOCK(&c->conn_mutex);
		return NULL;
	}

	TraceLog(LOG_INFO, "MPD CLIENT: CONNECTION: Successfully connected to a MPD server");

	LOCK(&c->conn_mutex);
	c->conn = conn;
	c->conn_state = CLIENT_CONN_STATE_READY;
	UNLOCK(&c->conn_mutex);

	return NULL;
}
void client_connect(Client *c) {
	assert(c->conn == NULL && c->conn_state == CLIENT_CONN_STATE_CONNECTING);

	pthread_t thread;
	pthread_create(&thread, NULL, do_connect, c);
}

void client_update(Client *c, State *state) {
	LOCK(&c->conn_mutex);
	ClientConnState conn_state = c->conn_state;
	UNLOCK(&c->conn_mutex);

	if (conn_state != CLIENT_CONN_STATE_READY) return;

	c->fetch_status_timer_ms -= (int)(GetFrameTime() * 1000);

	if (c->fetch_status_timer_ms <= 0) {
		fetch_status(c);
		c->fetch_status_timer_ms = CLIENT_FETCH_EVERY_MS;
	}

	if (TRYLOCK(&c->artwork_mutex) == 0) {
		if (c->artwork_just_changed) {
			if (c->artwork_exists) {
				state_set_artwork(state, c->artwork_image, c->artwork_average_color);
				UnloadImage(c->artwork_image);
				c->artwork_exists = false;
			} else {
				state_clear_artwork(state);
			}

			c->artwork_just_changed = false;
		}

		UNLOCK(&c->artwork_mutex);
	}
}

const char *song_tag_or_unknown(const struct mpd_song *song, enum mpd_tag_type tag) {
	const char *t = mpd_song_get_tag(song, tag, 0);
	return t == NULL ? UNKNOWN : t;
}

void client_run_play_song(Client *c, unsigned id) {
	if (!mpd_run_play_id(c->conn, id)) {
		CONN_HANDLE_ERROR(c->conn);
		return;
	}
	c->fetch_status_timer_ms = 0;
}
bool client_run_reorder(Client *c, unsigned from, unsigned to) {
	if (from == to) return true;

	bool res = mpd_run_move(c->conn, from, to);
	if (!res) CONN_HANDLE_ERROR(c->conn);
	return res;
}
void client_run_seek(Client *c, int seconds) {
	if (mpd_run_seek_current(c->conn, seconds, false))
		c->fetch_status_timer_ms = 0;
	else
		CONN_HANDLE_ERROR(c->conn);
}
void client_run_toggle(Client *c) {
	bool res = mpd_send_command(c->conn, "pause", NULL);
	res = res && mpd_response_finish(c->conn);
	if (res)
		c->fetch_status_timer_ms = 0;
	else
		CONN_HANDLE_ERROR(c->conn);
}
void client_run_next(Client *c) {
	if (mpd_run_next(c->conn))
		c->fetch_status_timer_ms = 0;
	else
		CONN_HANDLE_ERROR(c->conn);
}
void client_run_prev(Client *c) {
	if (mpd_run_previous(c->conn))
		c->fetch_status_timer_ms = 0;
	else
		CONN_HANDLE_ERROR(c->conn);
}

void client_free(Client *c) {
	if (c->conn) mpd_connection_free(c->conn);
	if (c->cur_song) mpd_song_free(c->cur_song);
	if (c->cur_status) mpd_status_free(c->cur_status);
}
