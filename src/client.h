#ifndef CLIENT_H
#define CLIENT_H

#include <raylib.h>
#include <pthread.h>
#include <mpd/client.h>

#include "./macros.h"
#include "./state.h"

#define STATUS_FETCH_INTERVAL_MS 250
#define ARTWORK_FETCH_DELAY_MS 200
#define ACTIONS_QUEUE_CAP 16
#define EVENTS_QUEUE_CAP 16

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
	// Playback status chagned (pause, resume, seek, etc...)
	EVENT_STATUS_CHANGED = 1 << 0,
	// Currently playing song was changed
	EVENT_SONG_CHANGED = 1 << 1,
	// Current queue was changed outside MUPWIT (something else made queue change)
	EVENT_QUEUE_CHANGED = 1 << 2,

	// Previous `ACTION_REORDER_QUEUE` failed for some reason
	EVENT_REORDER_QUEUE_FAILED = 1 << 3,
} Event;

typedef struct Client {
	ActionsQueue _actions;
	// Events bit mask
	// 0 - no events
	Event events;

	bool _polling_idle;
	int _status_fetch_timer;
	// Current queue was changed by user inside MUPWIT (queue entry was reordered, deleted, etc...)
	bool _queue_changed;

	// Currently playing song
	// Can be `NULL`
	struct mpd_song *cur_song;
	// File name of the currently playing song with exention
	// Can be `NULL`
	const char *cur_song_filename;
	// Current playback status
	// Can be `NULL`
	struct mpd_status *cur_status;

	// Whether `fetch_artwork()` should be tried to be called again
	bool _fetch_artwork_again;
	pthread_mutex_t _artwork_mutex;
	bool _artwork_exists;
	bool _artwork_changed;
	Color _artwork_average_color;
	Image _artwork_image;
	// Delay timer between each `fetch_artwork()` call
	int _artwork_fetch_delay;

	pthread_mutex_t _conn_mutex;
	ClientState _state;
	struct mpd_connection *_conn;
} Client;

// Logs connect error if any has occured and returns `true`, otherwise `false`
bool conn_handle_error(struct mpd_connection *conn, int line);
// Logs async error if any has occured and returns `true`, otherwise `false`
bool async_handle_error(struct mpd_async *async, int line);

#define CONN_HANDLE_ERROR(CONN) conn_handle_error(CONN, __LINE__)
#define ASYNC_HANDLE_ERROR(ASYNC) async_handle_error(ASYNC, __LINE__)

Client client_new(void);

void client_push_action(Client *c, Action action);
void client_push_action_kind(Client *c, ActionKind action);

// Connect to a MPD server
void client_connect(Client *c);

// Update client every frame
void client_update(Client *c, State *state);

// Free memory allocated by `Client`
void client_free(Client *c);

// Safely get client state
ClientState client_get_state(Client *c);

bool song_is_playing(Client *c, const struct mpd_song *song);
const char *song_tag_or_unknown(const struct mpd_song *song, enum mpd_tag_type tag);
const char *song_title_or_filename(Client *c, const struct mpd_song *song);

#endif
