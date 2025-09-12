#ifndef PLAYER_H
#define PLAYER_H

#include <mpd/client.h>

typedef struct Player {
	// Currently playing song
	// `NULL` means no current song
	struct mpd_song *cur_song;
	// Current playback status
	// `NULL` means no info is available
	struct mpd_status *cur_status;
} Player;

Player player_new(void);

#endif
