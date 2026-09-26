#+vet explicit-allocators

package mupwit

import "base:runtime"
import "core:log"
import "core:strings"
import "lib:ui"

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

// TODO!: should delete cached covers that are too old and not referenced by onyone.
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

_player_handle_cover_response :: proc(player: ^Player, res: Response_Cover) {
	has_slot, has_cover, loading: bool
	block: {
		slot: ^Cover_Cache_Slot
		slot, has_slot = &player._covers_cache[res.key]
		if !has_slot do break block

		cover: ^Cover
		cover, has_cover = slot.covers[res.size].?
		if !has_cover do break block

		loading = cover.loading
		if !cover.loading do break block

		cover.surface = res.surface
		cover.color = res.color
		cover.loading = false
		return
	}

	log.errorf(
		"Couldn't update cover with an invalid state: has_slot = %v, has_cover = %v, loading = %v",
		has_slot,
		has_cover,
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
	loader: ^Cover_Loader,
	can_request: bool,
	dt: Seconds,
) -> (
	should_request: bool,
) {
	cover, has_cover := loader.cover.?
	if COVER_REQ_DELAY > 0 && !has_cover {
		loader._alpha_timer = COVER_ALPHA_ANIM_DURATION
	}

	switch {
	case has_cover:
		if !cover.loading && loader._alpha_timer > 0 {
			loader._alpha_timer -= dt
			ui.dirty(true)
		}

	case COVER_REQ_DELAY <= 0:
		if !can_request do break
		if loader._alpha_timer < COVER_ALPHA_ANIM_DURATION {
			loader._alpha_timer = COVER_ALPHA_ANIM_DURATION
			should_request = true
		}
		// Code below should be optimized out.
		return should_request

	case !can_request:
		loader._req_timer = 0

	case loader._req_timer < COVER_REQ_DELAY:
		loader._req_timer += dt
		should_request = loader._req_timer >= COVER_REQ_DELAY
	}
	return should_request
}

cover_loader_alpha :: proc(loader: ^Cover_Loader) -> f32 {
	if !cover_exists(loader.cover) do return 0.0
	return ui.time_ease(loader._alpha_timer, COVER_ALPHA_ANIM_DURATION, .Sine_In_Out)
}
