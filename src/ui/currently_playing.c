#include "../theme.h"
#include "./currently_playing.h"
#include "./progress_bar.h"
#include "../pages/queue_page.h"

#define PADDING_LEFT 8
#define PADDING_RIGHT 16
#define GAP 8

void currently_playing_draw(Client *client, State *state) {
	// Show everywhere except player page
	float transition = state->page_transition;
	if (state->prev_page == PAGE_PLAYER) {
		// padd
	} else if (state->page == PAGE_PLAYER) {
		if (!tween_playing(&state->page_tween)) return;
		transition = 1.0 - transition;
	} else {
		transition = 1.0;
	}

	// TODO: refactor, this code is almost the same as in `player_page_draw()`
	const char *title = UNKNOWN;
	const char *artist = UNKNOWN;
	enum mpd_state playstate = MPD_STATE_UNKNOWN;
	unsigned elapsed_sec = 0;
	unsigned duration_sec = 0;

	if (client->cur_status) {
		playstate = mpd_status_get_state(client->cur_status);
		elapsed_sec = (unsigned)(mpd_status_get_elapsed_ms(client->cur_status) / 1000);
		duration_sec = mpd_status_get_total_time(client->cur_status);
	}

	if (client->cur_song) {
		title = song_title_or_filename(client, client->cur_song);
		artist = song_tag_or_unknown(client->cur_song, MPD_TAG_ARTIST);
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
	if (state->page != PAGE_QUEUE && state->prev_page != PAGE_QUEUE) {
		// Draw box border
		DrawRectangle(
			outer_rect.x,
			outer_rect.y,
			outer_rect.width,
			1,
			THEME_GRAY
		);
	}

	// Draw "play" button
	Icon play_icon = ICON_PLAY;
	if (playstate == MPD_STATE_PLAY) play_icon = ICON_PAUSE;
	if (draw_icon_button(state, play_icon, offset)) {
		client_push_action_kind(client, ACTION_TOGGLE);
	}
	offset.x += ICON_BUTTON_SIZE + GAP;

	float right_width = container.width - offset.x + GAP;

	// Draw song title
	offset.y += 2;
	Text text = {
		.text = title,
		.font = state->normal_font,
		.size = THEME_NORMAL_TEXT_SIZE,
		.pos = offset,
		.color = THEME_BLACK,
	};
	Vec title_size = draw_cropped_text(text, right_width, state->background);

	if (title_size.x < right_width) {
		// Draw song artist
		text.text = TextFormat(" - %s", artist);
		text.pos.x += title_size.x;
		text.color = THEME_GRAY;
		draw_cropped_text(text, right_width - title_size.x, state->background);
	}

	// Draw progress bar
	offset.y += ICON_BUTTON_SIZE - PROGRESS_BAR_HEIGHT*2 - 1;

	static ProgressBar bar = {0};
	bar.rect = rect(offset.x, offset.y, right_width, PROGRESS_BAR_HEIGHT),
	bar.progress = (float)elapsed_sec / (float)duration_sec,
	bar.color = THEME_BLACK,

	progress_bar_draw(state, &bar);

	if (bar.events & PROGRESS_BAR_DRAGGING) {
		elapsed_sec = (int)(bar.progress * duration_sec);
	}
	if (bar.events & PROGRESS_BAR_STOPPED) {
		client_push_action(client, (Action){
			ACTION_SEEK_SECONDS,
			{.seek_seconds = elapsed_sec}
		});
	}
}
