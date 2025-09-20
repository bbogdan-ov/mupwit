#ifndef CLIENT_H
#define CLIENT_H

#include <raylib.h>
#include <pthread.h>
#include <mpd/client.h>

#include "./state.h"
#include "./dynamic_array.h"

extern const char *UNKNOWN;

// Fetch the player status every N millis
#define CLIENT_FETCH_EVERY_MS (1000/20)

// Client connection state
typedef enum ClientConnState {
	CLIENT_CONN_STATE_CONNECTING,
	CLIENT_CONN_STATE_READY,
	CLIENT_CONN_STATE_ERROR,
} ClientConnState;

typedef struct Client {
	pthread_mutex_t status_mutex;
	// Currently playing song
	// `NULL` means no current song
	struct mpd_song *cur_song;
	const char *cur_song_filename;
	// Current playback status
	// `NULL` means no info is available
	struct mpd_status *cur_status;

	pthread_mutex_t artwork_mutex;
	// Artwork image (CPU) of the current song
	Image artwork_image;
	Color artwork_average_color;
	bool artwork_exists;
	bool artwork_just_changed;

	pthread_mutex_t conn_mutex;
	ClientConnState conn_state;
	struct mpd_connection *conn;

	// Time left untill trying to fetch the player status
	int fetch_status_timer_ms;
} Client;

// Logs an libmpdclient error if any has occured and returns `true`,
// otherwise `false`
bool conn_handle_error(struct mpd_connection *conn, int line);

#define CONN_HANDLE_ERROR(CONN) conn_handle_error(CONN, __LINE__)

Client client_new(void);

// Connect to a MPD server
void client_connect(Client *c);

// Update client every frame
void client_update(Client *c, State *state);

const char *song_tag_or_unknown(const struct mpd_song *song, enum mpd_tag_type tag);

void client_run_play_song(Client *c, unsigned id);
// Move song from position `from` to `to` (0-based)
bool client_run_reorder(Client *c, unsigned from, unsigned to);
void client_run_seek(Client *c, int seconds);
void client_run_toggle(Client *c);
void client_run_next(Client *c);
void client_run_prev(Client *c);

// Free memory allocated by `Client`
void client_free(Client *c);

#endif
