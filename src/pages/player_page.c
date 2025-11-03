#include <stdio.h>
#include <math.h>
#include <string.h>

#include "./player_page.h"
#include "../client.h"
#include "../theme.h"
#include "../macros.h"
#include "../ui/draw.h"
#include "../ui/button.h"
#include "../ui/progress_bar.h"

#define PADDING 32
#define GAP 16

// TODO: draw "no song" when no info about current song is available

static int artwork_frame = 0;
static int artwork_frame_timer = 0;

void draw_artwork(ArtworkImage *artwork, Texture empty_artwork, Rect rect, Color tint) {
#define FRAME_WIDTH 296
#define FRAMES_COUNT 4
#define FRAME_DELAY_MS (1000/2) // 2 fps

	if (artwork->exists)
		draw_texture_quad(artwork->texture, rect, tint);
	else {
		artwork_frame_timer -= (int)(GetFrameTime() * 1000);
		if (artwork_frame_timer <= 0) {
			artwork_frame = (artwork_frame + 1) % FRAMES_COUNT;
			artwork_frame_timer = FRAME_DELAY_MS;
		}

		Rect src = {artwork_frame * FRAME_WIDTH, 0, FRAME_WIDTH, empty_artwork.height};
		DrawTexturePro(empty_artwork, src, rect, (Vec){0}, 0, tint);
	}
}

void player_page_draw(Client *client, State *state, Assets *assets) {
	float transition = state->page_transition;
	if (state->page == PAGE_PLAYER && state->prev_page == PAGE_QUEUE) {
		// pass
	} else if (state->page == PAGE_PLAYER) {
		transition = 1.0;
	} else if (state->page == PAGE_QUEUE && state->prev_page == PAGE_PLAYER) {
		if (!tween_playing(&state->page_tween)) return;
		transition = 1.0 - transition;
	} else {
		return;
	}

	const struct mpd_song   *cur_song_nullable;
	const struct mpd_status *cur_status_nullable;
	client_lock_status_nullable(
		client,
		&cur_song_nullable,
		&cur_status_nullable
	);

	const char *title = UNKNOWN;
	const char *album = UNKNOWN;
	const char *artist = UNKNOWN;
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

		album = song_tag_or_unknown(cur_song_nullable, MPD_TAG_ALBUM);
		artist = song_tag_or_unknown(cur_song_nullable, MPD_TAG_ARTIST);
	}

	int sw = GetScreenWidth();
	int sh = GetScreenHeight();

	state->container = rect(-sw * 0.25 * (1.0 - transition), 0, sw, sh);
	state->container = rect_shrink(state->container, PADDING, PADDING);
	Vec offset = {state->container.x, state->container.y};

	// Draw artwork
	Rect artwork_rect = state->container;
	artwork_rect.height = artwork_rect.width;

	// Previous artwork
	draw_artwork(
		&state->prev_artwork,
		assets->empty_artwork,
		artwork_rect,
		WHITE
	);
	// Current artwork
	draw_artwork(
		&state->cur_artwork,
		assets->empty_artwork,
		artwork_rect,
		ColorAlpha(WHITE, state_artwork_alpha(state))
	);

	// Artwork border
	draw_box(assets, BOX_3D, rect_shrink(artwork_rect, -1, -1), THEME_BLACK);

	offset.y += artwork_rect.height + GAP;

	BeginScissorMode(
		state->container.x,
		state->container.y,
		state->container.width,
		state->container.height
	);

	// ==============================
	// Draw info
	// ==============================

	Text text = (Text){
		.text = title,
		.font = assets->title_font,
		.size = THEME_TITLE_TEXT_SIZE,
		.pos = offset,
		.color = THEME_TEXT,
	};

	// Draw song title
	Vec text_bounds = draw_cropped_text(text, state->container.width, state->background);
	offset.y += text_bounds.y;

	static char artist_str[128] = {0};
	snprintf(artist_str, 127, "%s - %s", artist, album);
	artist_str[127] = 0;

	// Draw artist and album
	text = (Text){
		.text = artist_str,
		.font = assets->normal_font,
		.size = THEME_NORMAL_TEXT_SIZE,
		.pos = offset,
		.color = THEME_SUBTLE_TEXT,
	};
	text_bounds = draw_cropped_text(text, state->container.width, state->background);
	offset.y += text_bounds.y;

	EndScissorMode();

	// Draw control buttons
	offset.y += GAP;

	draw_box(
		assets,
		BOX_ROUNDED,
		rect(offset.x, offset.y, ICON_BUTTON_SIZE * 3, ICON_BUTTON_SIZE),
		THEME_BLACK
	);

	// Previous button
	if (draw_icon_button(state, assets, ICON_PREV, offset)) {
		client_push_action_kind(client, ACTION_PREV);
	}
	offset.x += ICON_BUTTON_SIZE;

	// Play button
	Icon play_icon = ICON_PLAY;
	if (playstate == MPD_STATE_PLAY) play_icon = ICON_PAUSE;
	if (draw_icon_button(state, assets, play_icon, offset)) {
		client_push_action_kind(client, ACTION_TOGGLE);
	}
	offset.x += ICON_BUTTON_SIZE;

	// Next button
	if (draw_icon_button(state, assets, ICON_NEXT, offset)) {
		client_push_action_kind(client, ACTION_NEXT);
	}
	offset.x += ICON_BUTTON_SIZE;

	// Draw progress bar
	offset.x += GAP;
	offset.y += PROGRESS_BAR_HEIGHT + 1;

	static ProgressBar bar = {.draw_thumb = true};
	bar.rect = rect(
		offset.x,
		offset.y,
		state->container.width - ICON_BUTTON_SIZE*3 - GAP,
		PROGRESS_BAR_HEIGHT
	);
	bar.progress = (float)elapsed_sec / (float)duration_sec;
	bar.color = THEME_BLACK;

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

	// Draw time
	static char elapsed_str[TIME_BUF_LEN] = {0};
	static char duration_str[TIME_BUF_LEN] = {0};
	format_time(elapsed_str, elapsed_sec, false);
	format_time(duration_str, duration_sec, false);

	text.text = elapsed_str;
	text.pos = vec(bar.rect.x, bar.rect.y + PROGRESS_BAR_EXPAND + PROGRESS_BAR_HEIGHT * 2);
	draw_text(text);

	text.text = duration_str;
	Vec size = measure_text(&text);
	text.pos = vec(bar.rect.x + bar.rect.width - size.x, bar.rect.y + PROGRESS_BAR_EXPAND + PROGRESS_BAR_HEIGHT * 2);
	draw_text(text);

	offset.y += ICON_BUTTON_SIZE + PADDING;

	if (sh > offset.y) {
		// TODO: temporarily
		SetWindowSize(sw, offset.y);
	}

	client_unlock_status(client);
}
