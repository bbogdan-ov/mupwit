#+vet explicit-allocators

package mupwit

import "base:runtime"
import "core:container/lru"
import "core:log"
import "core:strings"

import "lib:cairo"
import "lib:mpd"
import "lib:ui"

COVER_CHANNELS :: 4 // Number of channels of each pixel in a cover surface.

MAX_COVER_CACHE_ENTRIES :: 28
MAX_COVER_DECODE_THREADS :: 4

Cover_Key :: struct {
	// Either an album name or a song file, because some songs may not have an album.
	str:  string,
	size: Cover_Size,
}

Cover_Size :: enum {
	Small = 0,
	Medium,
	Huge,
}

@(rodata)
COVER_SIZE := [Cover_Size]i32 {
	.Small  = COVER_SIZE_SMALL,
	.Medium = COVER_SIZE_MEDIUM,
	.Huge   = COVER_SIZE_HUGE,
}

Cover_Surface :: ^cairo.surface_t

Cover :: struct #all_or_none {
	allocator: runtime.Allocator,
	surface:   Maybe(Cover_Surface),
	color:     Color,
	ref_count: int,
	loading:   bool,
}

Cover_Cache_Entry :: struct {
	cover:     ^Cover,
	// Key allocator.
	allocator: runtime.Allocator,
}

Covers_Cache :: lru.Cache(Cover_Key, Cover_Cache_Entry)

cover_ref :: proc(cover: ^Cover, loc := #caller_location) -> ^Cover {
	assert(cover != nil, loc = loc)
	assert(cover.ref_count > 0, loc = loc)
	cover.ref_count += 1
	return cover
}

cover_unref :: proc(cover: ^Cover, loc := #caller_location) {
	assert(cover != nil, loc = loc)
	assert(cover.ref_count > 0, loc = loc)

	cover.ref_count -= 1
	if cover.ref_count > 0 do return

	if surface, ok := cover.surface.?; ok {
		cairo.surface_destroy(surface)
	}
	free(cover, cover.allocator, loc)
}

cover_maybe_unref :: proc(cover: Maybe(^Cover), loc := #caller_location) {
	if cover, ok := cover.?; ok {
		cover_unref(cover, loc)
	}
}

cover_key_make :: proc(file: mpd.Song_File, album: mpd.Album_Name, size: Cover_Size) -> Cover_Key {
	if len(album) > 0 {
		return Cover_Key{album, size}
	} else {
		assert(len(file) > 0)
		return Cover_Key{string(file), size}
	}
}
cover_key_clone :: proc(
	key: Cover_Key,
	allocator := context.allocator,
	loc := #caller_location,
) -> Cover_Key {
	s := strings.clone(string(key.str), allocator, loc)
	return Cover_Key{s, key.size}
}
cover_key_make_cloned :: proc(
	file: mpd.Song_File,
	album: mpd.Album_Name,
	size: Cover_Size,
	allocator := context.allocator,
	loc := #caller_location,
) -> Cover_Key {
	key := cover_key_make(file, album, size)
	return cover_key_clone(key, allocator, loc)
}
cover_key_delete :: proc(key: Cover_Key, allocator := context.allocator, loc := #caller_location) {
	delete(key.str, allocator, loc)
}

covers_cache_init :: proc(cache: ^Covers_Cache, allocator := context.allocator) {
	lru.init(cache, MAX_COVER_CACHE_ENTRIES, allocator, allocator)

	cache.on_remove = proc(key: Cover_Key, entry: Cover_Cache_Entry, userdata: rawptr) {
		// NOTE: someone may still have a reference to this cover, so this
		// `cover_unref` is not guaranteed to free the cover memory.
		cover_unref(entry.cover)
		cover_key_delete(key, entry.allocator)
	}
}

covers_cache_destroy :: proc(cache: ^Covers_Cache) {
	lru.destroy(cache, true)
}

cover_get :: proc(
	player: ^Base_Player,
	file: mpd.Song_File,
	album: mpd.Album_Name,
	size: Cover_Size,
) -> (
	cover: ^Cover,
	ok: bool,
) {
	assert(len(file) > 0)

	key := cover_key_make(file, album, size)
	entry := lru.get(&player._covers_cache, key) or_return
	return entry.cover, true
}

// Returns the pointer to the cached cover (without creating a reference) by a
// file or album name.
// If the cover is not cached, requests it, creates, caches and returns an
// empty one which will be updated upon receiving cover surface.
cover_get_or_request :: proc(
	player: ^Base_Player,
	file: mpd.Song_File,
	album: mpd.Album_Name,
	size: Cover_Size,
	loc := #caller_location,
) -> ^Cover {
	assert(len(file) > 0)

	temp_key := cover_key_make(file, album, size)

	entry, ok := lru.get(&player._covers_cache, temp_key)
	if ok {
		// Yay we've got a cached cover!
		return entry.cover
	}

	c := Cover {
		surface   = nil,
		color     = {},
		ref_count = 1,
		loading   = true,
		allocator = player.allocator,
	}
	cover := new_clone(c, c.allocator, loc)

	key := cover_key_clone(temp_key, player.allocator, loc)
	entry = Cover_Cache_Entry{cover, player.allocator}
	lru.set(&player._covers_cache, key, entry)

	player_request_cover(player, file, album, size)

	return cover
}

_player_handle_cover_response :: proc(player: ^Base_Player, res: Response_Cover) {
	has_entry, loading: bool
	block: {
		entry: ^Cover_Cache_Entry
		entry, has_entry = lru.get_ptr(&player._covers_cache, res.key)
		if !has_entry do break block

		cover := entry.cover
		loading = cover.loading
		if !cover.loading do break block

		cover.surface = res.surface
		cover.color = res.color
		cover.loading = false
		return
	}

	log.errorf(
		"Couldn't update cover with an invalid state: has_entry = %v, loading = %v",
		has_entry,
		loading,
	)
}

cover_rect :: proc(size: Cover_Size, pos: Vec2) -> Rect {
	return {pos.x, pos.y, COVER_SIZE[size], COVER_SIZE[size]}
}

cover_exists :: proc(cover: Maybe(^Cover)) -> bool {
	cover, has_cover := cover.?
	return has_cover && cover.surface != nil
}

cover_draw :: proc(
	cr: ^cairo.cairo_t,
	cover: Maybe(^Cover),
	pos: Vec2,
	alpha: f64 = 1,
) -> (
	drawn: bool,
) {
	if alpha <= 0 do return false

	cover, has_cover := cover.?
	if !has_cover do return false

	surface, has_surface := cover.surface.?
	if !has_surface do return false

	cairo.set_source_surface(cr, surface, f64(pos.x), f64(pos.y))
	cairo.paint_with_alpha(cr, alpha)

	return true
}

Cover_Loader :: struct {
	cover:        Maybe(^Cover),
	_req_timer:   Seconds,
	_alpha_timer: Seconds,
}

cover_loader_update :: proc(
	player: ^Base_Player,
	loader: ^Cover_Loader,
	file: mpd.Song_File,
	album: mpd.Album_Name,
	size: Cover_Size,
	can_request: bool,
	dt: Seconds,
) {
	cover, has_cover := loader.cover.?

	switch {
	case has_cover && !cover.loading && loader._alpha_timer <= 0: // Do nothing.

	case has_cover && !cover.loading:
		loader._alpha_timer -= dt
		ui.dirty(true)

	case has_cover:
		loader._alpha_timer = COVER_ALPHA_ANIM_DURATION

	case !can_request:
		loader._req_timer = 0

	case:
		cover, ok := cover_get(player, file, album, size)
		if ok {
			loader.cover = cover_ref(cover)
			ui.dirty(true)
			break
		}

		loader._req_timer += dt

		request := loader._req_timer >= COVER_REQ_DELAY
		if request {
			cover := cover_get_or_request(player, file, album, size)
			loader.cover = cover_ref(cover)
		}
	}

}

cover_loader_alpha :: proc(loader: ^Cover_Loader) -> f32 {
	if !cover_exists(loader.cover) do return 0.0
	return ui.time_ease(loader._alpha_timer, COVER_ALPHA_ANIM_DURATION, .Sine_In_Out)
}
