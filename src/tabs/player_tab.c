#include <stdio.h>
#include <math.h>
#include <string.h>
#include <mpd/client.h>

#include "../draw.h"
#include "../theme.h"
#include "player_tab.h"

#define BAR_HEIGHT 4
#define BAR_EXPAND 4

static const char *UNKNOWN = "<unknown>";

const char *format_time(int secs) {
	if (secs > 60 * 60) {
		return TextFormat("%02d:%02d:%02d", (int)(secs / 60 / 60), (int)(secs / 60) % 60, secs % 60);
	} else if (secs > 60) {
		return TextFormat("%02d:%02d", (int)(secs / 60), secs % 60);
	} else {
		return TextFormat("00:%02d", secs);
	}
}

const char *tag_or_unknown(struct mpd_song *song, enum mpd_tag_type tag) {
	const char *s = mpd_song_get_tag(song, tag, 0);
	return s != NULL ? s : UNKNOWN;
}

bool draw_icon_button(State *state, Icon icon, Vec pos) {
	Rect rec = rect(pos.x, pos.y, ICON_SIZE, ICON_SIZE);
	bool hover = CheckCollisionPointRec(GetMousePosition(), rec);

	if (hover && IsMouseButtonDown(MOUSE_BUTTON_LEFT))
		pos.y += 1;
	else if (hover)
		state->cursor = MOUSE_CURSOR_POINTING_HAND;

	draw_icon(state, icon, pos, THEME_BLACK);

	return hover && IsMouseButtonReleased(MOUSE_BUTTON_LEFT);
}

void draw_artwork(Artwork *artwork, Texture empty_artwork, Rect rect, Color tint) {
	static int frame = 0;
	static float frame_timer = 0;

	if (artwork->exists)
		draw_texture_quad(artwork->texture, rect, tint);
	else {
		frame_timer -= GetFrameTime();
		if (frame_timer <= 0) {
			frame += 1;
			if (frame > 3) frame = 0;

			frame_timer = 1.0 / 2.0;
		}

		DrawTexturePro(
			empty_artwork,
			(Rect){frame * 296, 0, 296, empty_artwork.height},
			rect,
			(Vec){0},
			0,
			tint
		);
	}
}

void player_tab_draw(Player *player, Client *client, State *state) {
	const char *title = NULL;
	const char *album = UNKNOWN;
	const char *artist = UNKNOWN;
	enum mpd_state playstate = MPD_STATE_UNKNOWN;
	unsigned elapsed_sec = 0;
	unsigned duration_sec = 0;

	if (player->cur_status) {
		playstate = mpd_status_get_state(player->cur_status);
		elapsed_sec = (unsigned)(mpd_status_get_elapsed_ms(player->cur_status) / 1000);
		duration_sec = mpd_status_get_total_time(player->cur_status);
	}

	if (player->cur_song) {
		title = mpd_song_get_tag(player->cur_song, MPD_TAG_TITLE, 0);
		if (title == NULL) {
			if (player->cur_song_filename)
				title = player->cur_song_filename;
			else
				title = UNKNOWN;
		}

		album = tag_or_unknown(player->cur_song, MPD_TAG_ALBUM);
		artist = tag_or_unknown(player->cur_song, MPD_TAG_ARTIST);
	}

	int sw = GetScreenWidth();
	int sh = GetScreenHeight();
	int padding = 32;
	int gap = 16;

	Rect container = rect_shrink(rect(0, 0, sw, sh), padding, padding);
	float offset_y = container.y;

	// Draw artwork
	Rect artwork_rect = rect(container.x, container.y, container.width, container.width);

	// Previous artwork
	draw_artwork(
		&state->prev_artwork,
		state->empty_artwork,
		artwork_rect,
		WHITE
	);
	// Current artwork
	float alpha = state->transition_progress * 8.0;
	if (alpha > 1.0) alpha = 1.0;
	draw_artwork(
		&state->cur_artwork,
		state->empty_artwork,
		artwork_rect,
		ColorAlpha(WHITE, alpha)
	);

	// Artwork border
	draw_box(state, BOX_3D, rect_shrink(artwork_rect, -1, -1), THEME_BLACK);

	offset_y += artwork_rect.height + gap;

	BeginScissorMode(container.x, container.y, container.width, container.height);

	// ==============================
	// Draw info
	// ==============================

	Vec text_offset = vec(container.x, offset_y);
	Text text = (Text){
		.text = title,
		.font = state->title_font,
		.size = THEME_TITLE_TEXT_SIZE,
		.pos = text_offset,
		.color = THEME_TEXT,
	};

	// Draw song title
	Vec text_bounds = draw_cropped_text(text, container.width, state->background);
	text_offset.y += text_bounds.y;

	// Draw artist and album
	text = (Text){
		.text = TextFormat("%s - %s", artist, album),
		.font = state->normal_font,
		.size = THEME_NORMAL_TEXT_SIZE,
		.pos = text_offset,
		.color = THEME_SUBTLE_TEXT,
	};
	text_bounds = draw_cropped_text(text, container.width, state->background);
	text_offset.y += text_bounds.y;

	EndScissorMode();

	// Draw control buttons
	text_offset.y += gap;

	draw_box(
		state,
		BOX_ROUNDED,
		rect(text_offset.x, text_offset.y, ICON_SIZE * 3, ICON_SIZE),
		THEME_BLACK
	);

	// Previous button
	if (draw_icon_button(state, ICON_PREV, text_offset)) {
		client_run_prev(client);
	}
	text_offset.x += ICON_SIZE;

	// Play button
	Icon play_icon = ICON_PLAY;
	if (playstate == MPD_STATE_PLAY) play_icon = ICON_PAUSE;
	if (draw_icon_button(state, play_icon, text_offset)) {
		client_run_toggle(client);
	}
	text_offset.x += ICON_SIZE;

	// Next button
	if (draw_icon_button(state, ICON_NEXT, text_offset)) {
		client_run_next(client);
	}
	text_offset.x += ICON_SIZE;

	// Draw progress bar
	text_offset.x += gap;
	text_offset.y += BAR_HEIGHT + 1;
	Rect bar_rect = rect(
		text_offset.x,
		text_offset.y,
		container.width + padding - text_offset.x,
		BAR_HEIGHT
	);
	draw_box(state, BOX_NORMAL, bar_rect, THEME_BLACK);

	static bool is_seeking = false;

	bool bar_hover = CheckCollisionPointRec(
		GetMousePosition(),
		rect_shrink(bar_rect, 0, -BAR_EXPAND)
	);
	float elapsed_progress = (float)elapsed_sec / (float)duration_sec;

	if (bar_hover)
		state->cursor = MOUSE_CURSOR_POINTING_HAND;
	if (!is_seeking && bar_hover && IsMouseButtonPressed(MOUSE_BUTTON_LEFT)) {
		is_seeking = true;
	}
	if (is_seeking) {
		float offset_x = GetMouseX() - bar_rect.x;
		elapsed_progress = offset_x / bar_rect.width;
		if (elapsed_progress > 1.0) elapsed_progress = 1.0;
		else if (elapsed_progress < 0.0) elapsed_progress = 0.0;

		elapsed_sec = (int)(elapsed_progress * duration_sec);

		if (!IsMouseButtonDown(MOUSE_BUTTON_LEFT)) {
			client_run_seek(client, elapsed_sec);
			is_seeking = false;
		}
	}

	// Draw progress bar fill
	Rect fill_rect = rect_shrink(bar_rect, 1, 1);
	fill_rect.width = floor(fill_rect.width * elapsed_progress);
	DrawRectangleRec(fill_rect, THEME_BLACK);

	// Draw progress bar thumb
	draw_icon(
		state,
		ICON_PROGRESS_THUMB,
		vec(
			fill_rect.x + fill_rect.width - ICON_SIZE/2,
			bar_rect.y + bar_rect.height/2 - ICON_SIZE/2
		),
		THEME_BLACK
	);

	// Draw time
	text.text = format_time(elapsed_sec);
	text.pos = vec(bar_rect.x, bar_rect.y + BAR_EXPAND + BAR_HEIGHT * 2);
	draw_text(text);

	text.text = format_time(duration_sec);
	Vec size = measure_text(&text);
	text.pos = vec(bar_rect.x + bar_rect.width - size.x, bar_rect.y + BAR_EXPAND + BAR_HEIGHT * 2);
	draw_text(text);

	text_offset.y += ICON_SIZE + padding;
	if (sh > text_offset.y) {
		// TODO: temporarily
		SetWindowSize(sw, text_offset.y);
	}
}
