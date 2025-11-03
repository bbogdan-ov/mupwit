#ifndef CLIENT_H
#define CLIENT_H

#include <raylib.h>
#include <pthread.h>
#include <mpd/client.h>

#include "./macros.h"
#include "./client/queue.h"
#include "./client/requests.h"

#include "../thirdparty/uthash.h"

#define STATUS_FETCH_INTERVAL_MS 250
#define POLL_IDLE_INTERVAL_MS (1000/30)
#define ARTWORK_FETCH_DELAY_MS 200
#define ACTIONS_QUEUE_CAP 16
#define ARTWORK_REQS_QUEUE_CAP 16
#define READY_ARTWORKS_QUEUE_CAP 8

extern const char *UNKNOWN;

// Client connection state
typedef enum ClientState {
	CLIENT_STATE_DEAD, // oh no! somebody help him!!
	CLIENT_STATE_CONNECTING,
	CLIENT_STATE_READY,
	CLIENT_STATE_ERROR,
} ClientState;

typedef enum ActionKind {
	ACTION_TOGGLE = 1,
	ACTION_NEXT,
	ACTION_PREV,
	// Seek currently playing song
	// Data: `seek_seconds`
	ACTION_SEEK_SECONDS,

	// Data: `song_id`
	ACTION_PLAY_SONG,

	// Data: `reorder`
	ACTION_REORDER_QUEUE,

	// Close connection
	ACTION_CLOSE,
} ActionKind;

typedef struct Action {
	ActionKind kind;
	union {
		unsigned song_id;
		unsigned seek_seconds;

		struct {
			unsigned from;
			unsigned to;
		} reorder;
	} data;
} Action;

typedef struct ActionsQueue {
	size_t head;
	size_t tail;
	size_t cap;
	Action buffer[ACTIONS_QUEUE_CAP];
} ActionsQueue;

typedef enum Event {
	// Half of second has passed
	EVENT_ELAPSED = 1 << 0,
	// Playback status chagned (pause, resume, seek, etc...)
	EVENT_STATUS_CHANGED = 1 << 1,
	// Currently playing song was changed
	EVENT_SONG_CHANGED = 1 << 2,
	// Current queue was changed outside MUPWIT (something else made queue change)
	EVENT_QUEUE_CHANGED = 1 << 3,

	// Previous `ACTION_REORDER_QUEUE` failed for some reason
	EVENT_REORDER_QUEUE_FAILED = 1 << 4,

	// Response received
	EVENT_RESPONSE = 1 << 5,
} Event;

typedef struct Client {
	pthread_mutex_t _actions_mutex;
	ActionsQueue _actions;

	pthread_mutex_t _acc_events_mutex;
	// Accomulated events
	Event _acc_events; // like back-buffer, but for events :)
	// Current events bit mask
	// Can be safely read and written
	Event events;

	pthread_mutex_t _reqs_mutex;
	Request *_reqs;
	Request *_cur_req;
	int _last_req_id;

	bool _polling_idle;
	int _status_fetch_timer;
	// Current queue was changed by the user inside MUPWIT
	// (queue item was reordered, deleted, etc...)
	bool _queue_changed;
	bool _should_close;

	pthread_mutex_t _status_mutex;
	// Currently playing song
	// Can be `NULL`
	struct mpd_song *_cur_song_nullable;
	// File name of the currently playing song with exention
	// Can be `NULL`
	const char *_cur_song_filename_nullable;
	// Current playback status
	// Can be `NULL`
	struct mpd_status *_cur_status_nullable;

	pthread_mutex_t _queue_mutex;
	Queue _queue;

	pthread_mutex_t _state_mutex;
	ClientState _state;
	struct mpd_connection *_conn;

	pthread_t _thread;
} Client;

// Logs connect error if any has occured and returns `true`, otherwise `false`
bool conn_handle_error(struct mpd_connection *conn, const char *file, int line);
// Logs async error if any has occured and returns `true`, otherwise `false`
bool async_handle_error(struct mpd_async *async, const char *file, int line);

#define CONN_HANDLE_ERROR(CONN) conn_handle_error(CONN, __FILE__, __LINE__)
#define ASYNC_HANDLE_ERROR(ASYNC) async_handle_error(ASYNC, __FILE__, __LINE__)

Client client_new(void);

void client_push_action(Client *c, Action action);
void client_push_action_kind(Client *c, ActionKind action);

void client_clear_events(Client *c);

// Make a request
// Returns id of the request
// Returns -1 if something went wrong
int client_request(Client *c, const char *song_uri);
// Get the requested artwork from `client_request()` if any
// Returns whether your artwork is ready and assigns `image` and `color`
// Assigned `image` and `color` may be zeroed which means there is no artwork image
bool client_request_poll_artwork(Client *c, int id, Image *image, Color *color);
void client_cancel_request(Client *c, int id);

// Connect to a MPD server
void client_connect(Client *c);

// Wait for the client thread to exit
void client_wait_for_thread(Client *c);

// Safely get client state
ClientState client_get_state(Client *c);

// Lock and get currently playing song and current playback status
// DON'T FORGET TO `client_unlock_status` IT BEFORE YOU'RE DONE DOING THINGS
// Can assign `NULL`s
void client_lock_status_nullable(
	Client *c,
	const struct mpd_song   **cur_song,
	const struct mpd_status **cur_status
);
// Unlock status mutex
void client_unlock_status(Client *c);

// Lock and get current queue
// DON'T FORGET TO `client_unlock_queue` IT BEFORE YOU'RE DONE DOING THINGS
const Queue *client_lock_queue(Client *c);
// Unlock queue mutex
void client_unlock_queue(Client *c);

const char *song_tag_or_unknown(const struct mpd_song *song, enum mpd_tag_type tag);

#endif
