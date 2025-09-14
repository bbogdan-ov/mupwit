#define _GNU_SOURCE

#include <assert.h>
#include <string.h>

#include "./player.h"

Player player_new(void) {
	return (Player){0};
}

void player_set_status(
	Player *p,
	struct mpd_status *cur_status,
	struct mpd_song *cur_song
) {
	p->cur_song = cur_song;
	p->cur_status = cur_status;

	// Update song filename
	if (cur_song) {
		const char *uri = mpd_song_get_uri(cur_song);
		const char *filename = NULL;
		if (uri) {
			filename = (const char*)memrchr(uri, '/', strlen(uri)) + 1;
			if (filename == NULL) filename = uri;
		}
		p->cur_song_filename = filename;
	} else {
		p->cur_song_filename = NULL;
	}
}
