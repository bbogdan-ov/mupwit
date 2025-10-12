#define _GNU_SOURCE

#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include <string.h>
#include <mpd/client.h>
#include <mpd/async.h>

#include "./client.h"
#include "./macros.h"

// TODO: fetch 'albumart' if 'readpicture' returned nothing

#define LOCK(MUTEX) assert(pthread_mutex_lock(MUTEX) == 0)
#define TRYLOCK(MUTEX) pthread_mutex_trylock(MUTEX)
#define UNLOCK(MUTEX) assert(pthread_mutex_unlock(MUTEX) == 0)

const char *UNKNOWN = "<unknown>";

bool conn_handle_error(struct mpd_connection *conn, int line) {
	enum mpd_error err = mpd_connection_get_error(conn);
	if (err != MPD_ERROR_SUCCESS) {
		const char *msg = mpd_connection_get_error_message(conn);
		TraceLog(LOG_ERROR, "MPD CLIENT (line %d): CONNECTION ERROR: %s (%d)", line, msg, err);
		return true;
	}
	return false;
}
bool async_handle_error(struct mpd_async *async, int line) {
	enum mpd_error err = mpd_async_get_error(async);
	if (err != MPD_ERROR_SUCCESS) {
		const char *msg = mpd_async_get_error_message(async);
		TraceLog(LOG_ERROR, "MPD CLIENT (line %d): ASYNC ERROR: %s (%d)", line, msg, err);
		return true;
	}
	return false;
}

Client client_new(void) {
	pthread_mutex_t conn_mutex;
	pthread_mutex_init(&conn_mutex, NULL);

	pthread_mutex_t artwork_mutex;
	pthread_mutex_init(&artwork_mutex, NULL);

	return (Client){
		._actions = (ActionsQueue){
			.cap = ACTIONS_QUEUE_CAP,
			.buffer = {{0}},
		},

		._artwork_mutex = artwork_mutex,
		._conn_mutex = conn_mutex,
	};
}

void client_push_action(Client *c, Action action) {
	RINGBUF_PUSH(&c->_actions, action);
}
void client_push_action_kind(Client *c, ActionKind action) {
	client_push_action(c, (Action){action, {0}});
}
Action pop_action(Client *c) {
	Action action = {0};
	RINGBUF_POP(&c->_actions, &action, (Action){0});
	return action;
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
		c->cur_song = NULL;
		c->cur_song_filename = NULL;
	}
}
void set_cur_status(Client *c, struct mpd_status *status) {
	if (c->cur_status) mpd_status_free(c->cur_status);
	c->cur_status = status;
}
void set_cur_song(Client *c, struct mpd_song *song) {
	if (c->cur_song) mpd_song_free(c->cur_song);
	c->cur_song = song;
}

// Read song album artwork into the specified buffer
// Returns size of the read buffer (0 - no artwork, -1 - error)
static int readpicture(
	Client *c,
	unsigned char **buffer,
	size_t capacity,
	char (*filetype)[16],
	const char *song_uri
) {
	size_t size = 0;

	while (true) {
		bool res = mpd_send_readpicture(c->_conn, song_uri, size);
		if (!res) {
			CONN_HANDLE_ERROR(c->_conn);
			return -1;
		}

		// Receive file type
		struct mpd_pair *pair = mpd_recv_pair_named(c->_conn, "type");
		if (pair != NULL) {
			memcpy(*filetype, pair->value, 15); // 16 - 1 (null-terminator)
			mpd_return_pair(c->_conn, pair);
		}

		// Receive current binary chunk size
		pair = mpd_recv_pair_named(c->_conn, "binary");
		if (pair == NULL) {
			// Clear the previous error because `recv_pair` will set an error
			// if there is no more fields
			if (!mpd_connection_clear_error(c->_conn)) {
				TraceLog(LOG_ERROR, "MPD CLIENT: readpicture(): Unexpected error!");
				CONN_HANDLE_ERROR(c->_conn);
				exit(1);
			}
			return 0; // no binary field => no artwork
		}
		const size_t chunk_size = strtoull(pair->value, NULL, 10);
		mpd_return_pair(c->_conn, pair);

		// Reallocate buffer if not enough memory
		if (size + chunk_size >= capacity) {
			capacity = (size + chunk_size) * 2;
			*buffer = realloc(*buffer, capacity);
		}

		if (!mpd_recv_binary(c->_conn, *buffer + size, chunk_size)) {
			TraceLog(LOG_ERROR, "MPD CLIENT: READING PICTURE (line %d): No binary data was provided in the response!", __LINE__);
			return -1;
		}

		if (!mpd_response_finish(c->_conn)) {
			TraceLog(LOG_ERROR, "MPD CLIENT: READING PICTURE (line %d): Unable to finish the response!", __LINE__);
			return -1;
		}

		// End of artwork file
		if (chunk_size == 0) break;

		size += chunk_size;
	}

	return size;
}

Color image_average_color(Image image) {
	int comps = 0;
	if (image.format == PIXELFORMAT_UNCOMPRESSED_R8G8B8)
		comps = 3;
	else if (image.format == PIXELFORMAT_UNCOMPRESSED_R8G8B8A8)
		comps = 4;

	// Calculate average color of the artwork
	Color color = {0};
	if (comps > 0) {
		unsigned char *data = image.data;
		float cr = 0.0, cg = 0.0, cb = 0.0;
		float n = 1.0;
		for (int i = 0; i < image.width * image.height * comps; i += comps) {
			int r = data[i + 0];
			int g = data[i + 1];
			int b = data[i + 2];
			float max = (float)MAX(r, MAX(g, b));
			float min = (float)MIN(r, MIN(g, b));
			float saturation = 0.0;
			float lightness = (max + min) / 2.0 / 255.0;
			if (max > 0) saturation = (max - min) / max;

			if (saturation >= 0.5 && lightness > 0.3) {
				n += 1.0;
				cr += r;
				cg += g;
				cb += b;
			}
			if (lightness >= 0.6) {
				n += 0.2;
				cr += r/5;
				cg += g/5;
				cb += b/5;
			}
		}

		color = (Color){
			(char)MAX(cr/n, 50.0),
			(char)MAX(cg/n, 50.0),
			(char)MAX(cb/n, 50.0),
			255
		};
	}

	return ColorBrightness(color, 0.4);
}

bool client_fetch_song_artwork(
	Client *c,
	const char *uri,
	void *(*thread_func)(void *)
) {
	size_t capacity = 1024 * 256; // 256KB
	unsigned char *buffer = malloc(capacity);
	char filetype[16] = {0};
	int size = readpicture(c, &buffer, capacity, &filetype, uri);

	// Simply return if there is an error or no artwork
	if (size <= 0) {
		free(buffer);
		return false;
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
		free(buffer);
		return false;
	}

	DecodeArtworkArgs *args = malloc(sizeof(DecodeArtworkArgs));
	args->client = c;
	args->buffer = buffer;
	args->buffer_size = size;
	args->filetype = img_filetype;

	pthread_t thread;
	pthread_create(&thread, NULL, thread_func, args);
	return true;
}

void *decode_artwork(void *args_) {
	DecodeArtworkArgs *args = args_;
	Client *c = args->client;

	LOCK(&c->_artwork_mutex);

	Image img = LoadImageFromMemory(
		args->filetype,
		args->buffer,
		args->buffer_size
	);

	c->_artwork_image = img;
	c->_artwork_exists = true;
	c->_artwork_changed = true;
	c->_artwork_average_color = image_average_color(img);

	UNLOCK(&c->_artwork_mutex);
	free(args->buffer);
	free(args);
	return NULL;
}

// Fetch album artwork of the currently playing song
void fetch_artwork(Client *c) {
	c->_fetch_artwork_again = false;
	c->_artwork_fetch_delay = ARTWORK_FETCH_DELAY_MS;

	// Free previous artwork image
	if (c->_artwork_exists) {
		UnloadImage(c->_artwork_image);
		c->_artwork_exists = false;
	}

	if (!c->cur_song) {
		c->_artwork_changed = true;
		c->_artwork_exists = false;
		return;
	}

	if (!client_fetch_song_artwork(c, mpd_song_get_uri(c->cur_song), decode_artwork)) {
		c->_artwork_changed = true;
		c->_artwork_exists = false;
	}
}

struct mpd_status *fetch_status(Client *c) {
	struct mpd_status *status = mpd_run_status(c->_conn);
	if (!status) {
		free_cur_status(c);
		return NULL;
	}

	set_cur_status(c, status);
	c->_status_fetch_timer = STATUS_FETCH_INTERVAL_MS;
	return status;
}
// Fetch playback status and currently playing song
// Returns `true` if song was changed, otherwise `false`
bool fetch_status_and_song(Client *c) {
	struct mpd_status *status = fetch_status(c);
	if (!status) return false;

	int cur_song_id = mpd_status_get_song_id(status);

	bool changed;
	if (c->cur_song) changed = cur_song_id != (int)mpd_song_get_id(c->cur_song);
	else             changed = cur_song_id >= 0;

	if (!changed) return changed;

	if (cur_song_id >= 0) {
		struct mpd_song *song = mpd_run_get_queue_song_id(c->_conn, cur_song_id);
		if (song) {
			// Set new current song
			set_cur_song(c, song);

			if (TRYLOCK(&c->_artwork_mutex) == 0) {
				if (c->_artwork_fetch_delay <= 0) {
					fetch_artwork(c);
				} else {
					c->_fetch_artwork_again = true;
					c->_artwork_fetch_delay = ARTWORK_FETCH_DELAY_MS;
				}
				UNLOCK(&c->_artwork_mutex);
			} else {
				c->_fetch_artwork_again = true;
			}

			return changed;
		}
	}

	// No info about current song
	free_cur_song(c);
	c->_artwork_changed = true;
	c->_artwork_exists = false;
	return changed;
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

	// TODO!: show "no server" message when connection was refused by the server
	if (CONN_HANDLE_ERROR(conn)) {
		mpd_connection_free(conn);

		// TODO: set error message somewhere
		LOCK(&c->_conn_mutex);
		c->_state = CLIENT_STATE_ERROR;
		UNLOCK(&c->_conn_mutex);
		return NULL;
	}

	TraceLog(LOG_INFO, "MPD CLIENT: CONNECTION: Successfully connected to a MPD server");

	LOCK(&c->_conn_mutex);
	c->_conn = conn;
	c->_state = CLIENT_STATE_READY;
	fetch_status_and_song(c);
	UNLOCK(&c->_conn_mutex);

	return NULL;
}
void client_connect(Client *c) {
	assert(c->_state == CLIENT_STATE_DEAD);

	pthread_t thread;
	pthread_create(&thread, NULL, do_connect, c);
}

bool run_toggle(Client *c) {
	bool res = mpd_send_command(c->_conn, "pause", NULL);
	if (res) {
		return mpd_response_finish(c->_conn);
	} else {
		CONN_HANDLE_ERROR(c->_conn);
		return false;
	}
}

bool recv_idle(Client *c, enum mpd_idle *idle) {
	struct mpd_async *async = mpd_connection_get_async(c->_conn);

	// Check whether there is something to receive/read
	if ((mpd_async_events(async) & MPD_ASYNC_EVENT_READ) == 0)
		return false;

	assert(mpd_async_io(async, MPD_ASYNC_EVENT_READ));

	// Receive all lines from the server till "OK"
	while (true) {
		char *line = mpd_async_recv_line(async);
		if (!line) {
			ASYNC_HANDLE_ERROR(async);
			return false;
		}

		if (strcmp(line, "OK") == 0) break;

		if (strcmp(line, "changed: player") == 0)   *idle |= MPD_IDLE_PLAYER;
		if (strcmp(line, "changed: playlist") == 0) *idle |= MPD_IDLE_PLAYLIST;
	}

	if (!mpd_response_finish(c->_conn)) {
		CONN_HANDLE_ERROR(c->_conn);
		return false;
	}

	return true;
}

void poll_idle(Client *c, enum mpd_idle *idle) {
	struct mpd_async *async = mpd_connection_get_async(c->_conn);

	if (c->_polling_idle) {
		if (recv_idle(c, idle))
			c->_polling_idle = false;
	} else {
		if (!mpd_async_send_command(async, "idle", NULL)) {
			ASYNC_HANDLE_ERROR(async);
			return;
		}

		assert(mpd_async_io(async, MPD_ASYNC_EVENT_WRITE));
		c->_polling_idle = true;
	}
}
void run_noidle(Client *c, enum mpd_idle *idle) {
	if (!c->_polling_idle) return;

	struct mpd_async *async = mpd_connection_get_async(c->_conn);

	bool res = mpd_async_send_command(async, "noidle", NULL);
	if (!res) {
		ASYNC_HANDLE_ERROR(async);
		return;
	}

	assert(mpd_async_io(async, MPD_ASYNC_EVENT_WRITE));

	// Sleep untill we receive all data from `noidle`
	while (!recv_idle(c, idle));
	c->_polling_idle = false;
}

static void handle_action(Client *c, Action action) {
	bool res;
	switch (action.kind) {
		case ACTION_TOGGLE:
			res = run_toggle(c);
			if (res) fetch_status(c);
			break;
		case ACTION_NEXT:
			res = mpd_run_next(c->_conn);
			if (res) fetch_status_and_song(c);
			break;
		case ACTION_PREV:
			res = mpd_run_previous(c->_conn);
			if (res) fetch_status_and_song(c);
			break;
		case ACTION_SEEK_SECONDS:
			res = mpd_run_seek_current(c->_conn, action.data.seek_seconds, false);
			if (res) fetch_status(c);
			break;

		case ACTION_PLAY_SONG:
			res = mpd_run_play_id(c->_conn, action.data.song_id);
			if (res) fetch_status(c);
			break;

		case ACTION_REORDER_QUEUE:
			res = mpd_run_move(c->_conn, action.data.reorder.from, action.data.reorder.to);
			if (res) c->_queue_changed = true;
			else     c->events |= EVENT_REORDER_QUEUE_FAILED;
			break;
	}
}

static void handle_idle(Client *c, enum mpd_idle idle) {
	if (idle & MPD_IDLE_PLAYER) {
		bool song_changed = fetch_status_and_song(c);

		c->events |= EVENT_STATUS_CHANGED;
		if (song_changed)
			c->events |= EVENT_SONG_CHANGED;
	}

	if (idle & MPD_IDLE_QUEUE) {
		if (c->_queue_changed)
			c->_queue_changed = false;
		else
			c->events |= EVENT_QUEUE_CHANGED;
	}
}

void client_update(Client *c, State *state) {
#define SHOULD_FETCH (c->_status_fetch_timer <= 0)

	if (client_get_state(c) != CLIENT_STATE_READY) return;

	c->events = 0;

	static int poll_timer = POLL_IDLE_INTERVAL_MS;

	int ms = (int)(GetFrameTime() * 1000);
	c->_status_fetch_timer -= ms;
	c->_artwork_fetch_delay -= ms;
	c->_artwork_fetch_delay = MAX(c->_artwork_fetch_delay, 0);
	poll_timer -= ms;

	Action action = pop_action(c);
	enum mpd_idle idle = 0;

	if (action.kind == 0 && !SHOULD_FETCH) {
		if (poll_timer <= 0) {
			poll_idle(c, &idle);
			poll_timer = POLL_IDLE_INTERVAL_MS;
		}
	} else {
		run_noidle(c, &idle);
	}

	// Eat all remaining actions
	while (true) {
		handle_action(c, action);

		action = pop_action(c);
		if (action.kind == 0) break;
	}

	handle_idle(c, idle);

	if (SHOULD_FETCH) {
		fetch_status(c);
		c->events |= EVENT_ELAPSED;
	}

	if (c->_fetch_artwork_again) {
		if (TRYLOCK(&c->_artwork_mutex) == 0) {
			if (c->_artwork_fetch_delay <= 0) {
				run_noidle(c, &idle);
				fetch_artwork(c);
			}
			UNLOCK(&c->_artwork_mutex);
		}
	}

	if (TRYLOCK(&c->_artwork_mutex) == 0) {
		if (c->_artwork_changed) {
			if (c->_artwork_exists) {
				state_set_artwork(state, c->_artwork_image, c->_artwork_average_color);
			} else {
				state_clear_artwork(state);
			}

			c->_artwork_changed = false;
		}

		UNLOCK(&c->_artwork_mutex);
	}
}

void client_free(Client *c) {
	free_cur_status(c);
	free_cur_song(c);
}

ClientState client_get_state(Client *c) {
	if (TRYLOCK(&c->_conn_mutex) == 0) {
		ClientState state = c->_state;
		UNLOCK(&c->_conn_mutex);
		return state;
	}
	return CLIENT_STATE_CONNECTING;
}

bool song_is_playing(Client *c, const struct mpd_song *song) {
	if (!c->cur_song) return false;
	return mpd_song_get_id(c->cur_song) == mpd_song_get_id(song);
}
const char *song_tag_or_unknown(const struct mpd_song *song, enum mpd_tag_type tag) {
	const char *t = mpd_song_get_tag(song, tag, 0);
	return t == NULL ? UNKNOWN : t;
}
const char *song_title_or_filename(Client *c, const struct mpd_song *song) {
	const char *title = mpd_song_get_tag(song, MPD_TAG_TITLE, 0);
	if (title == NULL) {
		if (c->cur_song_filename)
			title = c->cur_song_filename;
		else
			title = UNKNOWN;
	}
	return title;
}
