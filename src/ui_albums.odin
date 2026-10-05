package mupwit

import "core:log"
import "core:time"
import "lib:mpd"
import "lib:ui"

Album_Item :: struct {
	using item:  ui.Item,
	rect:        Rect,
	loader:      Cover_Loader,
	album_index: mpd.Album_Index,
}

Album_Item_List :: ui.Item_List(Album_Item)

@(private = "file")
self: struct {
	list:   Album_Item_List,
	scroll: ui.Scroll,
	box:    ui.Box,
}

albums_ui_init :: proc() {
	ui.item_list_init(&self.list, ALBUM_HEIGHT, context.allocator)
	self.list.kind = .Filterable
	self.list.item_width = ALBUM_WIDTH
	self.list.columns = ALBUM_GRID_COLUMS

	self.list.item_init = _album_item_init
	self.list.item_destroy = _album_item_destroy
	self.list.item_update = _album_item_update
	self.list.item_search_score = _album_item_search_score
}

albums_ui_destroy :: proc() {
	ui.item_list_destroy(&self.list)
}

albums_ui_update :: proc(state: ^State, dt: Seconds) {
	if state.screen != .Albums do return

	self.list.userdata = state
	ui.item_list_update(&self.box, &self.scroll, &self.list, dt)

	if ui.is_double_clicked(.Left) {
		_albums_ui_play_hovered_album(state)
	}
}

_albums_ui_play_hovered_album :: proc(state: ^State) -> bool {
	hovering := self.list.hovering.? or_return
	item := &self.list.items[hovering]
	album := state.player.albums[item.album_index]
	player_load_album(state.player, mpd.album_name(album))
	return true
}

albums_ui_draw :: proc(state: ^State, ctx: ^ui.Context) {
	if !screen_is_visible(state, .Albums) do return

	PAD_Y :: GAP + GAP / 2

	screen_box := ctx.box.rect

	box := ui.pad_b(screen_box, status_ui_visible_height() + clippy_ui_visible_height())
	box.x += screen_x_offset(state, .Albums)
	ui.guard_box(ctx, box, GAP, self.scroll.offset)
	self.box = ctx.box

	from, to := ui.item_list_visible_range(ctx.box, &self.list)
	to = min(to, ui.items_count(&self.list))
	for i in from ..< to {
		index := ui.Item_Index(i)
		item := &self.list.items[index]
		_album_item_draw(state, ctx, item, index)
	}

	contents := ui.item_list_content_height(&self.list)
	scroll_draw(state, ctx, &self.scroll, contents)
}

// ------------------------------
// Listeners.
// ------------------------------

albums_ui_on_scroll :: proc(state: ^State, scroll: f32, touchpad: bool) {
	if state.screen != .Albums do return

	ui.scroll_on_scroll(&self.scroll, scroll, touchpad)
}

albums_ui_on_keyboard_key :: proc(state: ^State, ev: Key_Event) -> (propagate: bool) {
	if state.screen != .Albums do return true

	self.list.userdata = state
	ui.item_list_on_keyboard_key(self.box, &self.scroll, &self.list, ev) or_return

	switch {
	case is_key(ev, .Enter):
		_albums_ui_play_hovered_album(state)
	}

	return true
}

albums_ui_on_search :: proc(state: ^State, search: string) {
	if state.screen != .Albums do return

	updated := ui.item_list_on_search(&self.list, search, context.allocator)
	if updated {
		start := time.now()
		ui.item_list_filter(&self.scroll, &self.list, len(state.player.albums))
		log.debugf("UI ALBUMS: Filtered items in %v", time.since(start))
	}
}

albums_ui_on_screen_updated :: proc(state: ^State) {
	if state.screen != .Albums do return
	clippy_ui_allow_search(.Albums, self.list.search)
}

albums_ui_on_album_list_updated :: proc(state: ^State) {
	ui.item_list_rebuild(&self.list, len(state.player.albums))
}

// ------------------------------
// Album item.
// ------------------------------

_album_item_init :: proc(list: ^Album_Item_List, item: ^Album_Item, index, number: ui.Item_Index) {
	item.album_index = mpd.Album_Index(index)
}

_album_item_destroy :: proc(item: ^Album_Item) {
	cover_maybe_unref(item.loader.cover)
}

_album_item_update :: proc(
	list: ^Album_Item_List,
	item: ^Album_Item,
	index: ui.Item_Index,
	dt: Seconds,
) {
	state := cast(^State)list.userdata

	pos := ui.item_pos_from_index(list, item.number)
	pos.y += -self.box.y - self.box.scroll

	album := state.player.albums[item.album_index]
	song := mpd.album_first_song(album)

	// NOTE: always allow to request a cover because albums are only being
	// updated when they are in the view (with a little offset from top and bottom).
	can_request := true
	cover_loader_update(
		state.player,
		&item.loader,
		song.file,
		song.album,
		.Medium,
		can_request,
		dt,
	)
}

_album_item_draw :: proc(
	state: ^State,
	ctx: ^ui.Context,
	item: ^Album_Item,
	index: ui.Item_Index,
) {
	album := &state.player.albums[item.album_index]

	pos := item.cur_position

	rect: Rect
	rect.x = ctx.box.x + pos.x
	rect.y = ctx.box.y + pos.y - ctx.box.scroll
	rect.width = self.list.item_width
	rect.height = self.list.item_height

	ui.guard_box(ctx, rect, GAP)

	if self.list.hovering == index {
		ui.draw_box(ctx, rect, state.theme.light_gray, filled = true)
	}

	offset: Vec2

	// Draw album cover.
	{
		rect := cover_rect(.Medium, rect_pos(ctx.box))
		alpha := cover_loader_alpha(&item.loader)

		// TODO: draw placeholder for a missing album cover.
		cover_draw(ctx, item.loader.cover, rect_pos(rect), f64(alpha))
		ui.draw_box_bulgy(ctx, ui.pad(rect, -1), state.theme.black)
		offset.y += rect.height
	}

	// Draw album name.
	{
		box := ctx.box
		box.y += offset.y
		box.height = ALBUM_HEIGHT - ALBUM_COVER_SIZE - GAP
		ui.guard_box(ctx, box)

		pos := rect_pos(ctx.box)
		pos.y += ctx.font_height
		pos.y += ctx.box.height / 2 - ctx.font_height / 2

		name := mpd.album_name(album^)
		ui.draw_text(ctx, name, pos, state.theme.black)
	}
}

_album_item_search_score :: proc(list: ^Album_Item_List, item: ^Album_Item) -> i32 {
	state := cast(^State)list.userdata
	album := state.player.albums[item.album_index]
	name := mpd.album_name(album)
	artist := mpd.album_artist(album)

	score := ui.item_list_calc_score(list, name)
	if score < ui.MIN_FILTER_SCORE {
		return ui.item_list_calc_score(list, artist)
	} else {
		return score
	}
}
