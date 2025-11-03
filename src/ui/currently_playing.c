#include "../theme.h"
#include "./currently_playing.h"
#include "./progress_bar.h"
#include "../pages/queue_page.h"

#define PADDING_LEFT 8
#define PADDING_RIGHT 16
#define GAP 8

void currently_playing_draw(Client *client, State *state, Assets *assets) {
	// Show everywhere except player page
	float transition = state->page_transition;
	if (state->prev_page == PAGE_PLAYER) {
		// padd
	} else if (state->page == PAGE_PLAYER) {
		if (!timer_playing(&state->page_tween)) return;
		transition = 1.0 - transition;
	} else {
		transition = 1.0;
	}

	const struct mpd_song   *cur_song_nullable;
	const struct mpd_status *cur_status_nullable;
	client_lock_status_nullable(
		client,
		&cur_song_nullable,
		&cur_status_nullable
	);

	// TODO: refactor, this code is almost the same as in `player_page_draw()`
	const char *title = UNKNOWN;
	const char *artist_nullable = NULL;
	enum mpd_state playstate = MPD_STATE_UNKNOWN;
	unsigned elapsed_sec = 0;
	unsigned duration_sec = 0;

	if (cur_status_nullable) {
		playstate = mpd_status_get_state(cur_status_nullable);
		elapsed_sec = (unsigned)(mpd_status_get_elapsed_ms(cur_status_nullable) / 1000);
		duration_sec = mpd_status_get_total_time(cur_status_nullable);
	}

	if (cur_song_nullable) {
		title = mpd_song_get_tag(cur_song_nullable, MPD_TAG_TITLE, 0);
		if (!title) {
			if (client->_cur_song_filename_nullable) {
				title = client->_cur_song_filename_nullable;
			} else {
				title = UNKNOWN;
			}
		}

		artist_nullable = mpd_song_get_tag(cur_song_nullable, MPD_TAG_ARTIST, 0);
	}

	int sw = GetScreenWidth();
	int sh = GetScreenHeight();

	float offset_y = QUEUE_STATS_HEIGHT * (1.0 - transition);
	Rect outer_rect = {
		0.0,
		sh - CUR_PLAY_HEIGHT * transition + offset_y,
		sw,
		CUR_PLAY_HEIGHT
	};
	Rect container = {
		outer_rect.x + PADDING_LEFT,
		outer_rect.y + CUR_PLAY_PADDING_Y,
		outer_rect.width - PADDING_LEFT - PADDING_RIGHT,
		outer_rect.height - CUR_PLAY_PADDING_Y*2,
	};
	Vec offset = {container.x, container.y};

	// Draw box
	DrawRectangleRec(outer_rect, state->background);
	// Draw box border
	DrawRectangle(
		outer_rect.x,
		outer_rect.y,
		outer_rect.width,
		1,
		THEME_GRAY
	);

	// Draw "play" button
	Icon play_icon = ICON_PLAY;
	if (playstate == MPD_STATE_PLAY) play_icon = ICON_PAUSE;
	if (draw_icon_button(state, assets, play_icon, offset)) {
		client_push_action_kind(client, ACTION_TOGGLE);
	}
	offset.x += ICON_BUTTON_SIZE + GAP;

	float right_width = container.width - offset.x + GAP;

	// Draw song title
	offset.y += 2;

	BeginScissorMode(
		offset.x,
		offset.y,
		right_width,
		THEME_NORMAL_TEXT_SIZE
	);

	Text text = {
		.text = title,
		.font = assets->normal_font,
		.size = THEME_NORMAL_TEXT_SIZE,
		.pos = offset,
		.color = THEME_BLACK,
	};
	Vec title_size = draw_cropped_text(text, right_width, state->background);

	if (artist_nullable && title_size.x < right_width) {
		// Draw song artist
		static char artist_str[128] = {0};
		snprintf(artist_str, 127, " - %s", artist_nullable);
		artist_str[127] = 0;

		text.text = artist_str;
		text.pos.x += title_size.x;
		text.color = THEME_GRAY;
		draw_cropped_text(text, right_width - title_size.x, state->background);
	}

	EndScissorMode();

	// Draw progress bar
	offset.y += ICON_BUTTON_SIZE - PROGRESS_BAR_HEIGHT*2 - 1;

	static ProgressBar bar = {0};
	bar.rect = rect(offset.x, offset.y, right_width, PROGRESS_BAR_HEIGHT),
	bar.progress = (float)elapsed_sec / (float)duration_sec,
	bar.color = THEME_BLACK,

	progress_bar_draw(&bar, state, assets);

	if (bar.events & PROGRESS_BAR_DRAGGING) {
		elapsed_sec = (int)(bar.progress * duration_sec);
	}
	if (bar.events & PROGRESS_BAR_STOPPED) {
		client_push_action(client, (Action){
			ACTION_SEEK_SECONDS,
			{.seek_seconds = elapsed_sec}
		});
	}

	client_unlock_status(client);
}
