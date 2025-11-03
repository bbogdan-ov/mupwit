#define _XOPEN_SOURCE 500

#include <string.h>

#include "./albums_page.h"
#include "../theme.h"
#include "../macros.h"
#include "../ui/draw.h"
#include "../ui/currently_playing.h"

#define ROW_COUNT 2 // number of alums in a single row

#define PADDING 8
#define GAP 8

AlbumsPage albums_page_new(void) {
	return (AlbumsPage){
		.scrollable = scrollable_new(),
	};
}

static float item_width = 0;
static float item_height = 0;

static void _album_item_draw(size_t idx, AlbumItem *item, State *state, Assets *assets) {
	Rect rect = {
		state->container.x + (idx % ROW_COUNT) * item_width,
		state->container.y - state->scroll + (idx / ROW_COUNT) * item_height,
		item_width,
		item_height
	};

	if (!CheckCollisionRecs(rect, screen_rect())) return;

	// ==============================
	// Draw item
	// ==============================

	Rect inner = rect_shrink(rect, PADDING, PADDING);
	Vec offset = {inner.x, inner.y};

	Color background = state->background;

	Vec mouse_pos = get_mouse_pos();
	bool is_hovering = CheckCollisionPointRec(mouse_pos, rect);
	is_hovering = is_hovering && CheckCollisionPointRec(mouse_pos, state->container);

	if (is_hovering) {
		// Draw background
		background = state->foreground;
		draw_box(assets, BOX_FILLED_ROUNDED, rect, background);

		state->cursor = MOUSE_CURSOR_POINTING_HAND;
	}

	// Draw artwork placeholder
	Rect artwork_rect = {offset.x, offset.y, inner.width, inner.width};
	draw_box(assets, BOX_3D, rect_shrink(artwork_rect, -1, -1), THEME_BLACK);
	offset.y += artwork_rect.height + GAP;

	// Draw title and artist
	Text text = {
		.text = item->artist_nullable ? item->artist_nullable : UNKNOWN,
		.font = assets->title_font,
		.size = THEME_TITLE_FONT_SIZE,
		.pos = vec(
			artwork_rect.x + PADDING,
			artwork_rect.y + artwork_rect.height - THEME_TITLE_FONT_SIZE - PADDING
		),
		.color = THEME_BLACK,
	};


	// Title
	BeginScissorMode(
		artwork_rect.x,
		artwork_rect.y,
		artwork_rect.width,
		artwork_rect.height
	);
	draw_text(text);
	EndScissorMode();

	// Artist
	BeginScissorMode(inner.x, inner.y, inner.width, inner.height);
	text.text = item->title;
	text.font = assets->normal_font,
	text.size = THEME_NORMAL_TEXT_SIZE;
	text.pos = offset;
	draw_cropped_text(text, inner.width, background);
	EndScissorMode();
}

void albums_page_draw(AlbumsPage *a, Client *client, State *state, Assets *assets) {
	float transition = state->page_transition;
	if (state->page == PAGE_ALBUMS && state->prev_page == PAGE_QUEUE) {
		// pass
	} else if (state->page == PAGE_ALBUMS) {
		transition = 1.0;
	} else if (state->page == PAGE_QUEUE && state->prev_page == PAGE_ALBUMS) {
		if (!timer_playing(&state->page_tween)) return;
		transition = 1.0 - transition;
	} else {
		return;
	}

	const Albums *albums = client_lock_albums(client);

	int sw = GetScreenWidth();
	int sh = GetScreenHeight();

	Rect container = rect(
		PADDING - sw * 0.25 * (1.0 - transition),
		PADDING,
		sw - PADDING*2,
		sh - PADDING*2 - CUR_PLAY_HEIGHT
	);

	// Calculate items size
	item_width = container.width / ROW_COUNT;
	item_height = item_width + THEME_NORMAL_TEXT_SIZE + PADDING;

	// Update scrollable
	float all_entries_height = albums->len/ROW_COUNT * item_height + item_height;
	scrollable_set_height(
		&a->scrollable,
		all_entries_height - container.height
	);
	scrollable_update(&a->scrollable);

	state->scroll = a->scrollable.scroll;
	state->container = container;

	// Draw scroll thumb
	scrollable_draw_thumb(&a->scrollable, state, state->foreground);

	// ==============================
	// Draw items
	// ==============================

	for (size_t i = 0; i < albums->len; i++) {
		AlbumItem *item = &albums->items[i];
		_album_item_draw(i, item, state, assets);
	}

	client_unlock_albums(client);
}
