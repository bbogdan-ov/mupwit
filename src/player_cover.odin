#+vet explicit-allocators

package mupwit

import "base:runtime"
import "core:strings"

import "lib:cairo"
import "lib:mpd"

COVER_CHANNELS :: 4 // Number of channels of each pixel in a cover surface.

MAX_COVER_DECODE_THREADS :: 4

// Either an album name or a song file, because some songs may not have an album.
Cover_Key :: distinct string

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

Cover_Cache_Slot :: struct #all_or_none {
	key:       Cover_Key,
	covers:    [Cover_Size]Maybe(^Cover),
	allocator: runtime.Allocator,
}

// TODO!: we should delete cached covers that are too old and not referenced by onyone.
Covers_Cache :: map[Cover_Key]Cover_Cache_Slot

cover_ref :: proc(cover: ^Cover) -> ^Cover {
	assert(cover != nil)
	assert(cover.ref_count > 0)
	cover.ref_count += 1
	return cover
}

// Last one to call this function must be the cache, so it can properly update
// the cache table.
cover_unref :: proc(cover: ^Cover) {
	assert(cover != nil)

	assert(cover.ref_count > 0)
	cover.ref_count -= 1
	if cover.ref_count > 0 do return

	if surface, ok := cover.surface.?; ok {
		cairo.surface_destroy(surface)
	}
	free(cover, cover.allocator)
}

cover_key_make :: proc(file: mpd.Song_File, album: mpd.Album_Name) -> Cover_Key {
	if len(album) > 0 {
		return Cover_Key(album)
	} else {
		assert(len(file) > 0)
		return Cover_Key(file)
	}
}
cover_key_clone :: proc(key: Cover_Key, allocator := context.allocator) -> Cover_Key {
	s := strings.clone(string(key), allocator)
	return Cover_Key(s)
}
cover_key_make_cloned :: proc(
	file: mpd.Song_File,
	album: mpd.Album_Name,
	allocator := context.allocator,
) -> Cover_Key {
	key := cover_key_make(file, album)
	return cover_key_clone(key, allocator)
}

_covers_cache_destroy :: proc(cache: Covers_Cache) {
	for _, slot in cache {
		_cover_cache_slot_destroy(slot)
	}
	delete(cache)
}

_cover_cache_slot_destroy :: proc(slot: Cover_Cache_Slot) {
	delete(string(slot.key), slot.allocator)
	for cover in slot.covers {
		c := cover.? or_continue
		// NOTE: this function is assumed to be called at the destraction of
		// the entire cache, which is called at the program end, therefore all
		// other objects referencing this cover will also be deleted, so no
		// worries if there are some dangling references left.
		c.ref_count = 1
		cover_unref(c)
	}
}

cover_get :: proc(
	player: ^Player,
	file: mpd.Song_File,
	album: mpd.Album_Name,
	size: Cover_Size,
) -> (
	cover: ^Cover,
	ok: bool,
) {
	assert(len(file) > 0)

	key := cover_key_make(file, album)
	slot := player._covers_cache[key] or_return
	return slot.covers[size].?
}

// Returns the pointer to the cached cover (without creating a reference) by a
// file or album name.
// If the cover is not cached, requests it, creates, caches and returns an
// empty one which will be updated upon receiving cover surface.
cover_get_or_request :: proc(
	player: ^Player,
	file: mpd.Song_File,
	album: mpd.Album_Name,
	size: Cover_Size,
) -> ^Cover {
	assert(len(file) > 0)

	temp_key := cover_key_make(file, album)

	slot, ok := &player._covers_cache[temp_key]
	if ok {
		cover, ok := slot.covers[size].?
		if ok {
			// Yay we've got a cached cover!
			return cover
		}
	} else {
		key := cover_key_clone(temp_key, player.allocator)
		player._covers_cache[key] = {
			key       = key,
			covers    = {},
			allocator = player.allocator,
		}
		slot = &player._covers_cache[key]
	}

	c := Cover {
		surface   = nil,
		color     = {},
		ref_count = 1,
		loading   = true,
		allocator = player.allocator,
	}
	cover := new_clone(c, player.allocator)
	slot.covers[size] = cover

	player_request_cover(player, file, album, size)

	return cover
}

_player_handle_response_cover :: proc(player: ^Player, res: Response_Cover) {
	slot, found := &player._covers_cache[res.key]
	assert(found) // TODO: handle error

	cover, has_cover := slot.covers[res.size].?
	assert(has_cover) // TODO: handle error

	cover.surface = res.surface
	cover.color = res.color
	cover.loading = false
}

Cover_Draw_Result :: enum {
	No_Cover = 0, // Cover does not exist.
	No_Surface, // Cover exists but the surface is missing, should draw a placeholder.
	Drawn, // Cover surface was drawn.
}

cover_rect :: proc(size: Cover_Size, pos: Vec2) -> Rect {
	return {pos.x, pos.y, COVER_SIZE[size], COVER_SIZE[size]}
}

cover_draw :: proc(
	cr: ^cairo.cairo_t,
	cover: Maybe(^Cover),
	pos: Vec2,
	alpha: f64 = 1,
) -> Cover_Draw_Result {
	cover, has_cover := cover.?
	if !has_cover do return .No_Cover

	surface, has_surface := cover.surface.?
	if !has_surface do return .No_Surface

	cairo.set_source_surface(cr, surface, f64(pos.x), f64(pos.y))
	cairo.paint_with_alpha(cr, alpha)

	return .Drawn
}
