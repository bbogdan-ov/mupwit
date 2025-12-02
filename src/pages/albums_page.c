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

Albums albums_page_new(void) {
	return (Albums){
		.items = NULL,
		.len = 0,
		.cap = 0,

		.scrollable = scrollable_new(),
	};
}

static float item_width = 0;
static float item_height = 0;

static AlbumItem _album_item_new(AlbumInfo info) {
	return (AlbumItem){
		.info = info,

		.artwork = artwork_image_new(),
		.artwork_tween = timer_new(300, false),
	};
}

static void _album_item_free(AlbumItem *item) {
	album_info_free(item->info);
}

static void _album_item_update_artwork(AlbumItem *item, Client *client, bool in_view) {
	if (item->artwork.received) return;

	// FIXME!!!!: artwork loading is annoyingly laggy! Needs to be fixed ASAP!

	if (artwork_image_is_fetching(&item->artwork)) {
		if (!in_view) {
			artwork_image_cancel(&item->artwork, client);
		}
	} else if (in_view) {
		artwork_image_fetch(&item->artwork, client, item->info.first_song_uri_nullable);
	}
}

static void _album_item_draw(size_t idx, AlbumItem *item, Context ctx) {
	Rect rect = {
		ctx.state->container.x + (idx % ROW_COUNT) * item_width,
		ctx.state->container.y - ctx.state->scroll + (idx / ROW_COUNT) * item_height,
		item_width,
		item_height
	};

	bool in_view = CheckCollisionRecs(rect, screen_rect());
	_album_item_update_artwork(item, ctx.client, in_view);

	if (!in_view) return;

	timer_update(&item->artwork_tween);

	// ==============================
	// Draw item
	// ==============================

	Rect inner = rect_shrink(rect, PADDING, PADDING);
	Vec offset = {inner.x, inner.y};

	Color background = ctx.state->background;

	Vec mouse_pos = get_mouse_pos();
	bool is_hovering = CheckCollisionPointRec(mouse_pos, rect);
	is_hovering = is_hovering && CheckCollisionPointRec(mouse_pos, ctx.state->container);

	if (is_hovering) {
		// Draw background
		background = ctx.state->foreground;
		draw_box(ctx.assets, BOX_FILLED_ROUNDED, rect, background);

		ctx.state->cursor = MOUSE_CURSOR_POINTING_HAND;
	}

	// Draw artwork
	Rect artwork_rect = {offset.x, offset.y, inner.width, inner.width};
	if (item->artwork.exists) {
		float alpha = timer_progress(&item->artwork_tween);
		draw_texture_quad(item->artwork.texture, artwork_rect, ColorAlpha(WHITE, alpha));
	}
	draw_box(ctx.assets, BOX_3D, rect_shrink(artwork_rect, -1, -1), THEME_BLACK);
	offset.y += artwork_rect.height + GAP;

	// Draw title and artist
	Text text = {
		.text = item->info.artist_nullable ? item->info.artist_nullable : UNKNOWN,
		.font = ctx.assets->title_font,
		.size = THEME_TITLE_FONT_SIZE,
		.pos = {0},
		.color = THEME_BLACK,
	};

	// Artist badge
	text.pos = vec(
		artwork_rect.x + PADDING*1.5,
		artwork_rect.y + artwork_rect.height - THEME_TITLE_FONT_SIZE - PADDING
	);

	Vec artist_text_size = measure_text(&text);
	Rect badge_rect = {
		text.pos.x,
		text.pos.y,
		MIN(artist_text_size.x, artwork_rect.width - PADDING*3),
		artist_text_size.y
	};

	draw_box(
		ctx.assets,
		BOX_FILLED_NORMAL,
		rect_shrink(badge_rect, -PADDING/2, 0),
		item->artwork.color
	);

	// Artist badge text
	BeginScissorMode(
		badge_rect.x,
		badge_rect.y,
		badge_rect.width,
		badge_rect.height
	);
	draw_cropped_text(
		text,
		badge_rect.width + 1,
		item->artwork.color
	);
	EndScissorMode();

	// Title
	BeginScissorMode(inner.x, inner.y, inner.width, inner.height);
	text.text = item->info.title;
	text.font = ctx.assets->normal_font,
	text.size = THEME_NORMAL_TEXT_SIZE;
	text.pos = offset;
	draw_cropped_text(text, inner.width, background);
	EndScissorMode();
}

static void _albums_update(Albums *a, EventDataAlbumsList data) {
	// Free previous items
	albums_page_free(a);

	for (size_t i = 0; i < data.len; i ++) {
		AlbumInfo info = data.items[i];
		DA_PUSH(a, _album_item_new(info));
	}

	// Free the array, but not its items, they are owned by `AlbumItem`s
	free(data.items);
	data.items = NULL;
}

void albums_page_on_event(Albums *a, Event event) {
	if (event.kind == EVENT_RESPONSE) {
		for (size_t i = 0; i < a->len; i++) {
			AlbumItem *item = &a->items[i];
			artwork_image_on_response_event(&item->artwork, event);
		}
	}

	else if (event.kind == EVENT_ALBUMS_LIST_CHANGED) {
		assert(event.data.albums.items != NULL);
		_albums_update(a, event.data.albums);
	}
}

void albums_page_draw(Albums *a, Context ctx) {
	float transition = ctx.state->page_transition;
	if (ctx.state->page == PAGE_ALBUMS && ctx.state->prev_page == PAGE_QUEUE) {
		// pass
	} else if (ctx.state->page == PAGE_ALBUMS) {
		transition = 1.0;
	} else if (ctx.state->page == PAGE_QUEUE && ctx.state->prev_page == PAGE_ALBUMS) {
		if (!timer_playing(&ctx.state->page_tween)) return;
		transition = 1.0 - transition;
	} else {
		return;
	}

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
	float all_entries_height = a->len/ROW_COUNT * item_height + item_height;
	scrollable_set_height(
		&a->scrollable,
		all_entries_height - container.height
	);
	scrollable_update(&a->scrollable);

	ctx.state->scroll = a->scrollable.scroll;
	ctx.state->container = container;

	// Draw scroll thumb
	scrollable_draw_thumb(&a->scrollable, ctx.state, ctx.state->foreground);

	// ==============================
	// Draw items
	// ==============================

	for (size_t i = 0; i < a->len; i++) {
		AlbumItem *item = &a->items[i];
		_album_item_draw(i, item, ctx);
	}
}

void albums_page_free(Albums *a) {
	for (size_t i = 0; i < a->len; i++) {
		_album_item_free(&a->items[i]);
	}
	free(a->items);
	a->len = 0;
	a->cap = 0;
	a->items = NULL;
}
