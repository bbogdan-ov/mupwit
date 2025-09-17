#ifndef CLIENT_H
#define CLIENT_H

#include <raylib.h>
#include <pthread.h>
#include <mpd/client.h>

#include "./player.h"
#include "./state.h"

extern const char *UNKNOWN;

// Update the player status every N millis
#define CLIENT_UPDATE_EVERY_MS 30

// Client connection state
typedef enum ClientConnState {
	CLIENT_CONN_STATE_CONNECTING,
	CLIENT_CONN_STATE_READY,
	CLIENT_CONN_STATE_ERROR,
} ClientConnState;

typedef struct Client {
	// Currently playing song
	// `NULL` means no current song
	struct mpd_song *cur_song;
	// Current playback status
	// `NULL` means no info is available
	struct mpd_status *cur_status;

	// Array of songs in the current queue
	// All entities types are guaranteed to be == MPD_ENTITY_TYPE_SONG
	struct mpd_entity **queue;
	size_t queue_len;
	// Queue dynamic array capacity in items (songs)
	size_t queue_cap;

	// Time left untill trying to update the player status
	int update_timer_ms;

	// Artwork image (CPU) of the current song
	Image artwork_image;
	Color artwork_average_color;
	bool has_artwork_image;
	bool artwork_image_changed;

	pthread_mutex_t mutex;
	pthread_mutex_t conn_state_mutex;
	ClientConnState conn_state;
	struct mpd_connection *conn;
} Client;

Client client_new(void);

// Connect to a MPD server
void client_connect(Client *c);

// Update client every frame
void client_update(Client *c, Player *player, State *state);

const char *song_tag_or_unknown(const struct mpd_song *song, enum mpd_tag_type tag);

void client_run_play_song(Client *c, unsigned id);
void client_run_seek(Client *c, int seconds);
void client_run_toggle(Client *c);
void client_run_next(Client *c);
void client_run_prev(Client *c);

// Free memory allocated by `Client`
void client_free(Client *c);

#endif
