#include <stdio.h>
#include <math.h>
#include <string.h>
#include <mpd/client.h>

#include "../draw.h"
#include "../theme.h"
#include "player_page.h"

#define BAR_HEIGHT 4
#define BAR_EXPAND 4
#define PADDING 32
#define GAP 16
#define BUTTON_SIZE 32

// TODO: draw "no song" when no info about current song is available

bool draw_icon_button(State *state, Icon icon, Vec pos) {
	Rect rec = rect(pos.x, pos.y, BUTTON_SIZE, BUTTON_SIZE);
	bool hover = CheckCollisionPointRec(get_mouse_pos(), rec);

	if (hover)
		state->cursor = MOUSE_CURSOR_POINTING_HAND;
	if (hover && IsMouseButtonDown(MOUSE_BUTTON_LEFT))
		pos.y += 1;

	pos.x += BUTTON_SIZE/2 - ICON_SIZE/2;
	pos.y += BUTTON_SIZE/2 - ICON_SIZE/2;
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

void player_page_draw(Client *client, State *state) {
	float transition = state->page_transition;
	if (state->page != PAGE_PLAYER) {
		if (state->prev_page == PAGE_PLAYER) {
			if (!tween_playing(&state->page_tween)) return;
			transition = 1.0 - transition;
		} else {
			return;
		}
	}

	LOCK(&client->mutex);

	const char *title = NULL;
	const char *album = UNKNOWN;
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
		title = mpd_song_get_tag(client->cur_song, MPD_TAG_TITLE, 0);
		if (title == NULL) {
			if (client->cur_song_filename)
				title = client->cur_song_filename;
			else
				title = UNKNOWN;
		}

		album = song_tag_or_unknown(client->cur_song, MPD_TAG_ALBUM);
		artist = song_tag_or_unknown(client->cur_song, MPD_TAG_ARTIST);
	}

	int sw = GetScreenWidth();
	int sh = GetScreenHeight();

	state->container = rect(-sw * 0.25 * (1.0 - transition), 0, sw, sh);
	state->container = rect_shrink(state->container, PADDING, PADDING);
	float offset_y = state->container.y;

	// Draw artwork
	Rect artwork_rect = state->container;
	artwork_rect.height = artwork_rect.width;

	// Previous artwork
	draw_artwork(
		&state->prev_artwork,
		state->empty_artwork,
		artwork_rect,
		WHITE
	);
	// Current artwork
	draw_artwork(
		&state->cur_artwork,
		state->empty_artwork,
		artwork_rect,
		ColorAlpha(WHITE, state_artwork_alpha(state))
	);

	// Artwork border
	draw_box(state, BOX_3D, rect_shrink(artwork_rect, -1, -1), THEME_BLACK);

	offset_y += artwork_rect.height + GAP;

	BeginScissorMode(
		state->container.x,
		state->container.y,
		state->container.width,
		state->container.height
	);

	// ==============================
	// Draw info
	// ==============================

	Vec text_offset = vec(state->container.x, offset_y);
	Text text = (Text){
		.text = title,
		.font = state->title_font,
		.size = THEME_TITLE_TEXT_SIZE,
		.pos = text_offset,
		.color = THEME_TEXT,
	};

	// Draw song title
	Vec text_bounds = draw_cropped_text(text, state->container.width, state->background);
	text_offset.y += text_bounds.y;

	// Draw artist and album
	text = (Text){
		.text = TextFormat("%s - %s", artist, album),
		.font = state->normal_font,
		.size = THEME_NORMAL_TEXT_SIZE,
		.pos = text_offset,
		.color = THEME_SUBTLE_TEXT,
	};
	text_bounds = draw_cropped_text(text, state->container.width, state->background);
	text_offset.y += text_bounds.y;

	EndScissorMode();

	// Draw control buttons
	text_offset.y += GAP;

	draw_box(
		state,
		BOX_ROUNDED,
		rect(text_offset.x, text_offset.y, BUTTON_SIZE * 3, BUTTON_SIZE),
		THEME_BLACK
	);

	// Previous button
	if (draw_icon_button(state, ICON_PREV, text_offset)) {
		client_run_prev(client);
	}
	text_offset.x += BUTTON_SIZE;

	// Play button
	Icon play_icon = ICON_PLAY;
	if (playstate == MPD_STATE_PLAY) play_icon = ICON_PAUSE;
	if (draw_icon_button(state, play_icon, text_offset)) {
		client_run_toggle(client);
	}
	text_offset.x += BUTTON_SIZE;

	// Next button
	if (draw_icon_button(state, ICON_NEXT, text_offset)) {
		client_run_next(client);
	}
	text_offset.x += BUTTON_SIZE;

	// Draw progress bar
	text_offset.x += GAP;
	text_offset.y += BAR_HEIGHT + 1;
	Rect bar_rect = rect(
		text_offset.x,
		text_offset.y,
		state->container.width - BUTTON_SIZE*3 - GAP,
		BAR_HEIGHT
	);
	draw_box(state, BOX_NORMAL, bar_rect, THEME_BLACK);

	static bool is_seeking = false;

	bool bar_hover = CheckCollisionPointRec(
		get_mouse_pos(),
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

	text_offset.y += BUTTON_SIZE + PADDING;
	if (sh > text_offset.y) {
		// TODO: temporarily
		SetWindowSize(sw, text_offset.y);
	}

	UNLOCK(&client->mutex);
}
