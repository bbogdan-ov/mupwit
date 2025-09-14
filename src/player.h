#ifndef PLAYER_H
#define PLAYER_H

#include <mpd/client.h>

typedef struct Player {
	// Currently playing song
	// `NULL` means no current song
	struct mpd_song *cur_song;
	const char *cur_song_filename;
	// Current playback status
	// `NULL` means no info is available
	struct mpd_status *cur_status;
} Player;

Player player_new(void);

void player_set_status(
	Player *p,
	struct mpd_status *cur_status,
	struct mpd_song *cur_song
);

#endif
