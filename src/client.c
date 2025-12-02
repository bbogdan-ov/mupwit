#define _GNU_SOURCE

#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include <errno.h>
#include <string.h>
#include <mpd/client.h>
#include <mpd/async.h>

#include "./client.h"
#include "./macros.h"
#include "./utils.h"

// TODO: fetch 'albumart' if 'readpicture' returned nothing

const char *UNKNOWN = "<unknown>";

bool conn_handle_error(struct mpd_connection *conn, const char *file, int line) {
	enum mpd_error err = mpd_connection_get_error(conn);
	if (err != MPD_ERROR_SUCCESS) {
		const char *msg = mpd_connection_get_error_message(conn);
		TraceLog(LOG_ERROR, "MPD CLIENT (at %s:%d): CONNECTION ERROR: %s (%d)", file, line, msg, err);
		mpd_connection_clear_error(conn); // ignore return error because we don't care
		return true;
	}
	return false;
}
bool async_handle_error(struct mpd_async *async, const char *file, int line) {
	enum mpd_error err = mpd_async_get_error(async);
	if (err != MPD_ERROR_SUCCESS) {
		const char *msg = mpd_async_get_error_message(async);
		TraceLog(LOG_ERROR, "MPD CLIENT (at %s:%d): ASYNC ERROR: %s (%d)", file, line, msg, err);
		return true;
	}
	return false;
}

#define INIT_MUTEX(NAME) \
	pthread_mutex_t NAME; \
	pthread_mutex_init(&NAME, &mattr);

#define INIT_RWLOCK(NAME) \
	pthread_rwlock_t NAME; \
	pthread_rwlock_init(&NAME, NULL);

Client client_new(void) {
	pthread_mutexattr_t mattr;
	assert(pthread_mutexattr_init(&mattr) == 0);
	assert(pthread_mutexattr_settype(&mattr, PTHREAD_MUTEX_ERRORCHECK) == 0);

	INIT_MUTEX(actions_mutex);

	INIT_MUTEX(events_mutex);
	INIT_MUTEX(reqs_mutex);

	INIT_RWLOCK(state_rwlock);
	INIT_RWLOCK(status_rwlock);

	return (Client){
		._actions_mutex = actions_mutex,
		._actions = (ActionsQueue){
			.cap = ACTIONS_QUEUE_CAP,
			.buffer = {{0}},
		},

		._events_mutex = events_mutex,
		._events = (EventsQueue){
			.cap = EVENTS_QUEUE_CAP,
			.buffer = {{0}},
		},

		._reqs_mutex = reqs_mutex,
		._reqs = NULL,
		._cur_req = NULL,
		._last_req_id = 0,

		._state_rwlock = state_rwlock,
		._status_rwlock = status_rwlock,
	};
}

void client_push_action(Client *c, Action action) {
	LOCK(&c->_actions_mutex);
	RINGBUF_PUSH(&c->_actions, action);
	UNLOCK(&c->_actions_mutex);
}
void client_push_action_kind(Client *c, ActionKind action) {
	client_push_action(c, (Action){action, {0}});
}
Action _client_pop_action(Client *c) {
	Action action = {0};
	LOCK(&c->_actions_mutex);
	RINGBUF_POP(&c->_actions, &action, (Action){0});
	UNLOCK(&c->_actions_mutex);
	return action;
}

static void _client_push_event(Client *c, Event event) {
	LOCK(&c->_events_mutex);
	RINGBUF_PUSH(&c->_events, event);
	UNLOCK(&c->_events_mutex);
}
Event client_pop_event(Client *c) {
	if (TRYLOCK(&c->_events_mutex) == 0) {
		Event event = {0};
		RINGBUF_POP(&c->_events, &event, (Event){0});
		UNLOCK(&c->_events_mutex);
		return event;
	}
	return (Event){0};
}

static void _client_free_request(Client *c, Request *req) {
	assert(req != NULL);
	assert(req->id > 0);

	if (req->canceled)
		TraceLog(LOG_INFO, "MPD CLIENT: Request %d was freed due being canceled", req->id);

	HASH_DEL(c->_reqs, req);
	free(req->song_uri);
	free(req);
}

void client_cancel_request(Client *c, int id) {
	assert(id > 0);

	LOCK(&c->_reqs_mutex);

	Request *req = NULL;
	HASH_FIND_INT(c->_reqs, &id, req);

	if (req) {
		req->canceled = true;
		TraceLog(LOG_INFO, "MPD CLIENT: Request %d canceled", req->id);
	}

	UNLOCK(&c->_reqs_mutex);
}

int client_request(Client *c, const char *song_uri) {
	LOCK(&c->_reqs_mutex);

	Request *req = calloc(1, sizeof(Request));
	req->id = ++ c->_last_req_id; // post-increment so id is always > 0
	req->song_uri = strdup(song_uri);
	req->canceled = false;

	HASH_ADD_INT(c->_reqs, id, req);
	TraceLog(LOG_INFO, "MPD CLIENT: Request %d has been made...", req->id);

	UNLOCK(&c->_reqs_mutex);
	return req->id;
}

void _client_free_cur_status(Client *c) {
	WRITE_LOCK(&c->_status_rwlock);
	if (c->_cur_status_nullable) {
		mpd_status_free(c->_cur_status_nullable);
		c->_cur_status_nullable = NULL;
	}
	RW_UNLOCK(&c->_status_rwlock);
}
void _client_free_cur_song(Client *c) {
	WRITE_LOCK(&c->_status_rwlock);
	if (c->_cur_song_nullable) {
		mpd_song_free(c->_cur_song_nullable);
		c->_cur_song_nullable = NULL;
		c->_cur_song_filename_nullable = NULL;
	}
	RW_UNLOCK(&c->_status_rwlock);
}
void _client_set_cur_status(Client *c, struct mpd_status *status) {
	WRITE_LOCK(&c->_status_rwlock);
	if (c->_cur_status_nullable)
		mpd_status_free(c->_cur_status_nullable);
	c->_cur_status_nullable = status;
	RW_UNLOCK(&c->_status_rwlock);
}
void _client_set_cur_song(Client *c, struct mpd_song *song) {
	WRITE_LOCK(&c->_status_rwlock);
	if (c->_cur_song_nullable)
		mpd_song_free(c->_cur_song_nullable);

	c->_cur_song_nullable = song;
	c->_cur_song_filename_nullable = path_basename(mpd_song_get_uri(song));

	RW_UNLOCK(&c->_status_rwlock);
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
				TraceLog(
					LOG_ERROR,
					"MPD CLIENT: readpicture(): Unexpected error occured when trying to receive 'binary' pair!"
				);
				CONN_HANDLE_ERROR(c->_conn);
				abort();
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

typedef struct DecodeArtworkArgs {
	Client *client;
	const char *filetype;
	unsigned char *buffer;
	int buffer_size;

	int req_id;
} DecodeArtworkArgs;

static void *_decode_artwork(void *args_) {
	DecodeArtworkArgs *args = args_;
	Client *c = args->client;

	Image image = LoadImageFromMemory(
		args->filetype,
		args->buffer,
		args->buffer_size
	);

	Color color = image_average_color(image);

	_client_push_event(c, (Event){
		.kind = EVENT_RESPONSE,
		.data = {
			.response_artwork = {
				.id = args->req_id,
				.image = image,
				.color = color,
			}
		}
	});

	free(args->buffer);
	free(args);
	return NULL;
}

// Returns whether artwork was successfully fetched
bool _client_fetch_song_artwork(Client *c, const Request *req) {
	assert(req != NULL);
	assert(req->id > 0);
	assert(!req->canceled);

	size_t capacity = 1024 * 256; // 256KB
	unsigned char *buffer = malloc(capacity);
	char filetype[16] = {0};
	int size = readpicture(c, &buffer, capacity, &filetype, req->song_uri);

	// Simply return if there is an error or no artwork
	if (size <= 0) {
		free(buffer);
		goto nope;
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
		goto nope;
	}

	DecodeArtworkArgs *args = malloc(sizeof(DecodeArtworkArgs));
	args->client = c;
	args->buffer = buffer;
	args->buffer_size = size;
	args->filetype = img_filetype;
	args->req_id = req->id;

	pthread_t thread;
	pthread_create(&thread, NULL, _decode_artwork, args);
	return true;

nope:
	return false;
}

struct mpd_status *_client_fetch_status(Client *c) {
	struct mpd_status *status = mpd_run_status(c->_conn);
	if (!status) {
		_client_free_cur_status(c);
		return NULL;
	}

	_client_set_cur_status(c, status);
	// Reset fetch timer so we don't fetch status twice if timer is finished
	c->_status_fetch_timer = STATUS_FETCH_INTERVAL_MS;
	return status;
}
// Fetch playback status and currently playing song
// Returns `true` if song was changed, otherwise `false`
bool _client_fetch_status_and_song(Client *c) {
	struct mpd_status *status = _client_fetch_status(c);
	if (!status) return false;

	int new_song_id = mpd_status_get_song_id(status);

	bool changed;
	const struct mpd_song *cur_song_nullable;
	client_lock_status_nullable(c, &cur_song_nullable, NULL);
	{
		if (cur_song_nullable)
			changed = new_song_id != (int)mpd_song_get_id(cur_song_nullable);
		else
			changed = new_song_id >= 0;
	}
	client_unlock_status(c);

	if (!changed) return changed;

	if (new_song_id >= 0) {
		struct mpd_song *song = mpd_run_get_queue_song_id(c->_conn, new_song_id);
		if (song) {
			// Set new current song
			_client_set_cur_song(c, song);
			return changed;
		}
	}

	// No info about current song
	_client_free_cur_song(c);
	return changed;
}

void _client_fetch_queue(Client *c) {
	clock_t start = clock();

	bool res = mpd_send_list_queue_meta(c->_conn);
	if (!res) {
		CONN_HANDLE_ERROR(c->_conn);
		return;
	}

	EventDataQueue queue = {0};

	DA_RESERVE(&queue, 512);

	// Receive queue entities/songs from the server
	while (true) {
		struct mpd_entity *entity = mpd_recv_entity(c->_conn);
		if (entity == NULL) {
			CONN_HANDLE_ERROR(c->_conn);
			break;
		}

		enum mpd_entity_type typ = mpd_entity_get_type(entity);
		if (typ == MPD_ENTITY_TYPE_SONG)
			DA_PUSH(&queue, entity);
	}

	clock_t end = clock();
	int time = (int)((double)(end - start) / CLOCKS_PER_SEC * 1000);
	TraceLog(LOG_INFO, "MPD CLIENT: QUEUE: Updated in %dms (%d songs)", time, queue.len);

	// Push event
	_client_push_event(c, (Event){
		.kind = EVENT_QUEUE_CHANGED,
		.data = { .queue = queue }
	});
}

static int _items_sort_func(const void* a, const void* b) {
	const AlbumInfo *ai = a;
	const AlbumInfo *bi = b;
	return strcmp(ai->title, bi->title);
}
void _client_fetch_albums(Client *c) {
	clock_t start = clock();

	// TODO: also group by the "disk" tag
	if (false
		|| !mpd_search_db_tags(c->_conn, MPD_TAG_ALBUM)
		|| !mpd_search_add_group_tag(c->_conn, MPD_TAG_ARTIST)
		|| !mpd_search_commit(c->_conn)
	) {
		CONN_HANDLE_ERROR(c->_conn);
		return;
	}

	EventDataAlbumsList albums = {0};

	// Collect all albums and their artists
	char *cur_artist = NULL;
	while (true) {
		struct mpd_pair *pair = mpd_recv_pair(c->_conn);
		if (!pair) break;

		if (strcmp(pair->name, "Artist") == 0) {
			free(cur_artist);
			cur_artist = strdup(pair->value);
		}

		if (strcmp(pair->name, "Album") == 0 && strlen(pair->value) > 0) {
			AlbumInfo info = {
				.title = strdup(pair->value),
				.artist_nullable = cur_artist ? strdup(cur_artist) : NULL,
				.first_song_uri_nullable = NULL,
			};
			DA_PUSH(&albums, info);
		}

		mpd_return_pair(c->_conn, pair);
	}
	free(cur_artist);

	qsort(albums.items, albums.len, sizeof(albums.items[0]), _items_sort_func);

	if (!mpd_response_finish(c->_conn)) {
		CONN_HANDLE_ERROR(c->_conn);
		return;
	}

	// Fetch first song of each album
	for (size_t i = 0; i < albums.len; i++) {
		AlbumInfo *info = &albums.items[i];

		if (false
			|| !mpd_search_db_songs(c->_conn, true)
			|| !mpd_search_add_tag_constraint(c->_conn, MPD_OPERATOR_DEFAULT, MPD_TAG_ALBUM, info->title)
			|| !mpd_search_add_window(c->_conn, 0, 1)
			|| !mpd_search_commit(c->_conn)
		) {
			CONN_HANDLE_ERROR(c->_conn);
			continue;
		}

		// Receive info for the first song in the album
		{
			struct mpd_pair *pair = mpd_recv_pair_named(c->_conn, "file");
			if (!pair) continue;

			info->first_song_uri_nullable = strdup(pair->value);

			mpd_return_pair(c->_conn, pair);
		}

		if (!mpd_response_finish(c->_conn))
			CONN_HANDLE_ERROR(c->_conn);
	}

	clock_t end = clock();
	int time = (int)((double)(end - start) / CLOCKS_PER_SEC * 1000);
	TraceLog(LOG_INFO, "MPD CLIENT: ALBUMS LIST: Updated in %dms (%d albums)", time, albums.len);

	// Push event
	_client_push_event(c, (Event){
		.kind = EVENT_ALBUMS_LIST_CHANGED,
		.data = { .albums = albums },
	});
}

bool _conn_run_toggle(struct mpd_connection *conn) {
	bool res = mpd_send_command(conn, "pause", NULL);
	if (res) {
		return mpd_response_finish(conn);
	} else {
		CONN_HANDLE_ERROR(conn);
		return false;
	}
}

bool _client_recv_idle(Client *c, enum mpd_idle *idle) {
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

void _client_poll_idle(Client *c, enum mpd_idle *idle) {
	struct mpd_async *async = mpd_connection_get_async(c->_conn);

	if (c->_polling_idle) {
		if (_client_recv_idle(c, idle))
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
void _client_noidle(Client *c, enum mpd_idle *idle) {
	if (!c->_polling_idle) return;

	struct mpd_async *async = mpd_connection_get_async(c->_conn);

	bool res = mpd_async_send_command(async, "noidle", NULL);
	if (!res) {
		ASYNC_HANDLE_ERROR(async);
		return;
	}

	assert(mpd_async_io(async, MPD_ASYNC_EVENT_WRITE));

	// Sleep untill we receive all data from `noidle`
	while (!_client_recv_idle(c, idle));
	c->_polling_idle = false;
}

static void _client_handle_action(Client *c, Action action) {
	if (action.kind <= 0) return;

	struct mpd_connection *conn = c->_conn;

	bool res = 0;
	switch (action.kind) {
		case ACTION_TOGGLE:
			res = _conn_run_toggle(conn);
			if (res) _client_fetch_status(c);
			break;
		case ACTION_NEXT:
			res = mpd_run_next(conn);
			if (res) {
				_client_fetch_status_and_song(c);
				_client_push_event(c, (Event){.kind = EVENT_SONG_CHANGED});
			}
			break;
		case ACTION_PREV:
			res = mpd_run_previous(conn);
			if (res) {
				_client_fetch_status_and_song(c);
				_client_push_event(c, (Event){.kind = EVENT_SONG_CHANGED});
			}
			break;
		case ACTION_SEEK_SECONDS:
			res = mpd_run_seek_current(conn, action.data.seek_seconds, false);
			if (res) _client_fetch_status(c);
			break;

		case ACTION_PLAY_SONG:
			res = mpd_run_play_id(conn, action.data.song_id);
			if (res) _client_fetch_status(c);
			break;

		case ACTION_REORDER_QUEUE:
			res = mpd_run_move(conn, action.data.reorder.from, action.data.reorder.to);
			if (res) c->_queue_changed = true;
			break;

		case ACTION_CLOSE:
			c->_should_close = true;
			break;
	}

	if (!res)
		CONN_HANDLE_ERROR(conn);
}

static void _client_handle_idle(Client *c, enum mpd_idle idle) {
	if (idle & MPD_IDLE_PLAYER) {
		bool song_changed = _client_fetch_status_and_song(c);

		_client_push_event(c, (Event){.kind = EVENT_STATUS_CHANGED});
		if (song_changed)
			_client_push_event(c, (Event){.kind = EVENT_SONG_CHANGED});
	}

	if (idle & MPD_IDLE_QUEUE) {
		if (c->_queue_changed) {
			c->_queue_changed = false;
		} else {
			// Fetch queue if it was changed outside MUPWIT
			_client_fetch_queue(c);
		}
	}

	if (idle & MPD_IDLE_DATABASE) {
		_client_fetch_albums(c);
	}
}

static void _client_fetch_requests(Client *c, enum mpd_idle *idle) {
	if (TRYLOCK(&c->_reqs_mutex) != 0) return;

	// Return if `_reqs` table is empty
	if (!c->_reqs) goto defer;
	if (!c->_cur_req) c->_cur_req = c->_reqs;

	if (!c->_cur_req->canceled) {
		_client_noidle(c, idle);
		_client_fetch_song_artwork(c, c->_cur_req);
	}

	Request *to_free = c->_cur_req;
	c->_cur_req = c->_cur_req->hh.next;
	_client_free_request(c, to_free);

defer:
	UNLOCK(&c->_reqs_mutex);
}

void _client_free(Client *c) {
	// Free allocated memory by the client
	mpd_connection_free(c->_conn);
	_client_free_cur_status(c);
	_client_free_cur_song(c);
}

// Client loop
// Runs 30 times per second in a separate thread
void _client_loop(Client *c) {
#define SHOULD_FETCH (c->_status_fetch_timer <= 0)
#define INTERVAL_MS (1000/30)

	if (client_get_state(c) != CLIENT_STATE_READY) return;

	// Elapsed time since previous interation
	int elapsed = 0;
	int poll_timer = POLL_IDLE_INTERVAL_MS;

	// TODO!: come up with a mechanism to wait on main thread untill all
	// the action are handled.
	// Currently if you, for example, seek the current song using the progress
	// bar in the player, it may jitter a little, that's because after we
	// pushed an action to seek the song it is not guaranteed to be handled or
	// response will arrive untill the next frame and new value for
	// the progress bar just isn't ready yet.

	while (true) {
		clock_t start = clock();

		c->_status_fetch_timer -= elapsed;
		poll_timer -= elapsed;

		Action action = _client_pop_action(c);
		enum mpd_idle idle = 0;

		// Poll idle
		if (action.kind == 0 && !SHOULD_FETCH) {
			if (poll_timer <= 0) {
				_client_poll_idle(c, &idle);
				poll_timer = POLL_IDLE_INTERVAL_MS;
			}
		} else {
			_client_noidle(c, &idle);
		}

		// Eat all remaining actions
		while (true) {
			_client_handle_action(c, action);

			action = _client_pop_action(c);
			if (action.kind == 0) break;
		}

		if (c->_should_close) break;

		_client_fetch_requests(c, &idle);

		_client_handle_idle(c, idle);

		// Fetch status
		if (SHOULD_FETCH) {
			_client_fetch_status(c);
			_client_push_event(c, (Event){.kind = EVENT_ELAPSED});
		}

		clock_t end = clock();
		double time = (double)(end - start) / CLOCKS_PER_SEC * 1000;
		elapsed = (int)(time + INTERVAL_MS);

		SLEEP_MS(INTERVAL_MS);
	}

	_client_free(c);

	TraceLog(LOG_INFO, "MPD CLIENT: Connection was successfully closed");
}

void _client_set_state(Client *c, ClientState state) {
	WRITE_LOCK(&c->_state_rwlock);
	c->_state = state;
	RW_UNLOCK(&c->_state_rwlock);
}

ClientState client_get_state(Client *c) {
	if (READ_TRYLOCK(&c->_state_rwlock) == 0) {
		ClientState state = c->_state;
		RW_UNLOCK(&c->_state_rwlock);
		return state;
	}
	return CLIENT_STATE_CONNECTING;
}

void *do_connect(void *client) {
	TraceLog(LOG_INFO, "MPD CLIENT: CONNECTION: Connecting to a MPD server...");

	// TODO: allow users to pass custom host and port via cli args
	struct mpd_connection *conn = mpd_connection_new(NULL, 0, 0);

	// Check for errors
	if (conn == NULL) {
		TraceLog(LOG_ERROR, "MPD CLIENT: CONNECTION: Out of memory!");
		abort();
	}

	Client *c = (Client*)client;

	// TODO!: show "no server" message when connection was refused by the server
	if (CONN_HANDLE_ERROR(conn)) {
		mpd_connection_free(conn);

		// TODO: set error message somewhere
		_client_set_state(c, CLIENT_STATE_ERROR);
		return NULL;
	}

	TraceLog(LOG_INFO, "MPD CLIENT: CONNECTION: Successfully connected to a MPD server");

	c->_conn = conn;
	_client_set_state(c, CLIENT_STATE_READY);

	_client_fetch_status_and_song(c);
	_client_fetch_queue(c);
	_client_fetch_albums(c);

	_client_loop(c);

	return NULL;
}
void client_connect(Client *c) {
	assert(client_get_state(c) == CLIENT_STATE_DEAD);

	int res = pthread_create(&c->_thread, NULL, do_connect, c);
	if (res != 0) {
		// TODO: print human-readable error code
		TraceLog(LOG_ERROR, "MPD CLIENT: Unable to create client's thread: %d", res);
		abort();
	}
}

void client_wait_for_thread(Client *c) {
	int res = pthread_join(c->_thread, NULL);
	if (res != 0) {
		// TODO: print human-readable error code
		TraceLog(LOG_ERROR, "MPD CLIENT: Unable to join client's thread: %d", res);
		abort();
	}
}

void client_lock_status_nullable(
	Client *c,
	const struct mpd_song   **cur_song,
	const struct mpd_status **cur_status
) {
	READ_LOCK(&c->_status_rwlock);
	if (cur_song)   *cur_song   = c->_cur_song_nullable;
	if (cur_status) *cur_status = c->_cur_status_nullable;
}
void client_unlock_status(Client *c) {
	RW_UNLOCK(&c->_status_rwlock);
}

const char *song_tag_or_unknown(const struct mpd_song *song, enum mpd_tag_type tag) {
	const char *t = mpd_song_get_tag(song, tag, 0);
	return t == NULL ? UNKNOWN : t;
}

void album_info_free(AlbumInfo a) {
	free(a.title);
	free(a.artist_nullable);
	free(a.first_song_uri_nullable);
	a.title = NULL;
	a.artist_nullable = NULL;
	a.first_song_uri_nullable = NULL;
}
