#include <raylib.h>

#include "./queue_page.h"
#include "../macros.h"
#include "../draw.h"
#include "../theme.h"

void queue_page_draw(Client *client, State *state) {
	// TODO: do not lock the client
	LOCK(&client->mutex);
	for (size_t i = 0; i < client->queue_len; i++) {
		const struct mpd_song *song = mpd_entity_get_song(client->queue[i]);

		Text text = {
			.text = TextFormat(
				"%s - %s",
				mpd_song_get_tag(song, MPD_TAG_ARTIST, 0),
				mpd_song_get_tag(song, MPD_TAG_TITLE, 0)
			),
			.font = state->normal_font,
			.size = THEME_NORMAL_TEXT_SIZE,
			.pos = {10, 10 + i * THEME_NORMAL_TEXT_SIZE},
			.color = THEME_BLACK,
		};
		draw_text(text);
	}
	UNLOCK(&client->mutex);
}
