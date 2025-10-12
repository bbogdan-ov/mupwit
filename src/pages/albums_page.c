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
		.entries = (AlbumEntriesList){0},

		.scrollable = scrollable_new(),
	};
}

static void entry_free(AlbumEntry *entry) {
	free(entry->title);
	free(entry->artist_nullable);
}

static float entry_width = 0;
static float entry_height = 0;

static void *decode_entry_artwork(void *args_) {
	DecodeArtworkArgs *args = args_;
	AlbumEntry *e = args->arg;

	LOCK(&e->artwork_mutex);

	Image img = LoadImageFromMemory(
		args->filetype,
		args->buffer,
		args->buffer_size
	);

	e->artwork_image_nullable = img;
	e->artwork_is_ready = true;

	UNLOCK(&e->artwork_mutex);
	free(args->buffer);
	free(args);
	return NULL;
}

static void entry_fetch_artwork(AlbumEntry *e, Client *client) {
	if (!e->first_song_uri_nullable) return;

	RINGBUF_PUSH(&client->artwork_requests, ((ArtworkRequest){
		.arg = e,
		.song_uri = e->first_song_uri_nullable,
		.decode_func = decode_entry_artwork,
	}));
}

static void entry_draw(size_t idx, AlbumEntry *e, Client *client, State *state) {
	Rect rect = {
		state->container.x + (idx % ROW_COUNT) * entry_width,
		state->container.y - state->scroll + (idx / ROW_COUNT) * entry_height,
		entry_width,
		entry_height
	};

	if (!CheckCollisionRecs(rect, screen_rect())) return;

	if (!e->waiting_for_artwork) {
		entry_fetch_artwork(e, client);
		e->waiting_for_artwork = true;
	} else if (!e->artwork_texture_loaded) {
		if (TRYLOCK(&e->artwork_mutex) == 0) {
			if (e->artwork_is_ready) {
				if (e->artwork_image_nullable.data != NULL) {
					Texture tex = LoadTextureFromImage(e->artwork_image_nullable);
					SetTextureFilter(tex, TEXTURE_FILTER_BILINEAR);

					e->artwork_texture_nullable = tex;
					UnloadImage(e->artwork_image_nullable);
				}
				e->artwork_texture_loaded = true;
			}
			UNLOCK(&e->artwork_mutex);
		}
	}

	// ==============================
	// Draw entry
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
		draw_box(state, BOX_FILLED_ROUNDED, rect, background);

		state->cursor = MOUSE_CURSOR_POINTING_HAND;
	}

	// Draw artwork
	Rect artwork_rect = {offset.x, offset.y, inner.width, inner.width};
	if (e->artwork_texture_nullable.id > 0)
		draw_texture_quad(
			e->artwork_texture_nullable,
			artwork_rect,
			WHITE
		);
	draw_box(state, BOX_3D, rect_shrink(artwork_rect, -1, -1), THEME_BLACK);
	offset.y += artwork_rect.height + GAP;

	// Draw title and artist
	Text text = {
		.text = e->artist_nullable ? e->artist_nullable : UNKNOWN,
		.font = state->title_font,
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
	text.text = e->title;
	text.font = state->normal_font,
	text.size = THEME_NORMAL_TEXT_SIZE;
	text.pos = offset;
	draw_cropped_text(text, inner.width, background);
	EndScissorMode();
}

int entries_sort_func(const void* a, const void* b) {
	const AlbumEntry *ae = a;
	const AlbumEntry *be = b;
	return strcmp(ae->title, be->title);
}
void fetch_albums(AlbumsPage *a, Client *client) {
	struct mpd_connection *conn = client->_conn;

	if (false
		|| !mpd_search_db_tags(conn, MPD_TAG_ALBUM)
		|| !mpd_search_add_group_tag(conn, MPD_TAG_ARTIST)
		|| !mpd_search_commit(conn)
	) {
		CONN_HANDLE_ERROR(conn);
		return;
	}

	// Free previous entries
	for (size_t i = 0; i < a->entries.len; i++) {
		entry_free(&a->entries.items[i]);
	}
	a->entries.len = 0;
	DA_RESERVE(&a->entries, 64);

	// Collect all albums and their artists
	char *cur_artist = NULL;
	while (true) {
		struct mpd_pair *pair = mpd_recv_pair(conn);
		if (!pair) break;

		if (strcmp(pair->name, "Artist") == 0) {
			cur_artist = strdup(pair->value);
		}

		if (strcmp(pair->name, "Album") == 0 && strlen(pair->value) > 0) {
			AlbumEntry entry = {
				.title = strdup(pair->value),
				.artist_nullable = cur_artist ? strdup(cur_artist) : NULL,
			};
			DA_PUSH(&a->entries, entry);
		}

		mpd_return_pair(conn, pair);
	}

	qsort(
		a->entries.items,
		a->entries.len,
		sizeof(a->entries.items[0]),
		entries_sort_func
	);

	if (!mpd_response_finish(conn))
		CONN_HANDLE_ERROR(conn);

	// ==============================
	// Fetch first song of each album
	// ==============================
	for (size_t i = 0; i < a->entries.len; i++) {
		AlbumEntry *entry = &a->entries.items[i];

		if (false
			|| !mpd_search_db_songs(conn, true)
			|| !mpd_search_add_tag_constraint(conn, MPD_OPERATOR_DEFAULT, MPD_TAG_ALBUM, entry->title)
			|| !mpd_search_add_window(conn, 0, 1)
			|| !mpd_search_commit(conn)
		) {
			CONN_HANDLE_ERROR(conn);
			continue;
		}

		// Receive info for the first song in the album
		{
			struct mpd_pair *pair = mpd_recv_pair_named(conn, "file");
			if (!pair) continue;

			entry->first_song_uri_nullable = strdup(pair->value);

			mpd_return_pair(conn, pair);
		}

		if (!mpd_response_finish(conn))
			CONN_HANDLE_ERROR(conn);
	}
}

void albums_page_update(AlbumsPage *a, Client *client) {
	static bool initialized = false;

	// TODO: update albums list when database has been updated
	if (!initialized) {
		fetch_albums(a, client);
		initialized = true;
	}
}

void albums_page_draw(AlbumsPage *a, Client *client, State *state) {
	float transition = state->page_transition;
	if (state->page == PAGE_ALBUMS && state->prev_page == PAGE_QUEUE) {
		// pass
	} else if (state->page == PAGE_ALBUMS) {
		transition = 1.0;
	} else if (state->page == PAGE_QUEUE && state->prev_page == PAGE_ALBUMS) {
		if (!tween_playing(&state->page_tween)) return;
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

	// Calculate entries size
	entry_width = container.width / ROW_COUNT;
	entry_height = entry_width + THEME_NORMAL_TEXT_SIZE + PADDING;

	// Update scrollable
	float all_entries_height = a->entries.len/ROW_COUNT * entry_height + entry_height;
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
	// Draw entries
	// ==============================

	for (size_t i = 0; i < a->entries.len; i++) {
		AlbumEntry *entry = &a->entries.items[i];
		entry_draw(i, entry, client, state);
	}
}

void albums_page_free(AlbumsPage *a) {
	for (size_t i = 0; i < a->entries.len; i++) {
		entry_free(&a->entries.items[i]);
	}
	a->entries.len = 0;
}
