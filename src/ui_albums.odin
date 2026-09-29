package mupwit

import "lib:mpd"
import "lib:ui"

Album_Item :: struct {
	using item:  ui.Item,
	rect:        Rect,
	album_index: mpd.Album_Index,
	loader:      Cover_Loader,
}

@(private = "file")
self: struct {
	list:   ui.Item_List(Album_Item),
	scroll: ui.Scroll,
	box:    ui.Box,
}

albums_ui_init :: proc() {
	ui.item_list_init(&self.list, ALBUM_HEIGHT, context.allocator)
	self.list.item_width = ALBUM_WIDTH
	self.list.columns = ALBUM_GRID_COLUMS
	self.list.item_update = album_ui_list_item_update
}

albums_ui_destroy :: proc() {
	_album_ui_clear_list()
	ui.item_list_destroy(&self.list)
}

albums_ui_update :: proc(state: ^State, dt: Seconds) {
	if state.screen != .Albums do return

	self.list.userdata = state
	ui.item_list_update(&self.box, &self.scroll, &self.list, dt)

	hovering, has_hovering := self.list.hovering.?
	if has_hovering && ui.is_double_clicked(.Left) {
		item := &self.list.items[hovering]
		album := state.player.albums[item.album_index]
		player_play_album(&state.player, mpd.album_name(album))
	}
}

albums_ui_draw :: proc(state: ^State, ctx: ^ui.Context) {
	if !screen_is_visible(state, .Albums) do return

	box := ui.pad_b(ctx.box, status_ui_visible_height())
	box.x += screen_x_offset(state, .Albums)
	ui.begin_box(ctx, box, GAP, self.scroll.offset)
	self.box = ctx.box

	from, to := ui.item_list_visible_range(ctx.box, &self.list)
	for i in from ..< to {
		if i >= ui.items_count(&self.list) do break

		index := ui.Item_Index(i)
		item := &self.list.items[index]
		album_item_draw(state, ctx, item, index)
	}

	contents := ui.item_list_content_height(&self.list)
	scroll_draw(state, ctx, &self.scroll, contents)
}

albums_ui_on_scroll :: proc(state: ^State, scroll: f32, touchpad: bool) {
	if state.screen != .Albums do return

	ui.scroll_on_scroll(&self.scroll, scroll, touchpad)
}

albums_ui_on_keyboard_key :: proc(state: ^State, ev: Key_Event) -> (propagate: bool) {
	if state.screen != .Albums do return true

	ui.item_list_on_keyboard_key(self.box, &self.scroll, &self.list, ev) or_return
	return true
}

albums_ui_on_album_list_updated :: proc(state: ^State) {
	_album_ui_clear_list()
	non_zero_reserve(&self.list.items, len(state.player.albums))

	for _, i in state.player.albums {
		index := ui.Item_Index(i)
		item := Album_Item {
			item        = ui.item_make(&self.list, index),
			album_index = mpd.Album_Index(i),
		}
		append(&self.list.items, item)
	}
}

album_ui_list_item_update :: proc(
	list: ^ui.Item_List(Album_Item),
	item: ^Album_Item,
	index: ui.Item_Index,
	dt: Seconds,
) {
	state := cast(^State)list.userdata

	pos := _album_item_pos(index)
	pos.y += -self.box.y - i32(self.box.scroll)

	is_in_view := -ALBUM_HEIGHT < pos.y && pos.y < self.box.height

	album := state.player.albums[item.album_index]
	song := mpd.album_first_song(album)

	cover_loader_update(
		&state.player,
		&item.loader,
		song.file,
		song.album,
		.Medium,
		is_in_view,
		dt,
	)
}

album_item_destroy :: proc(item: ^Album_Item) {
	cover_maybe_unref(item.loader.cover)
}

album_item_draw :: proc(state: ^State, ctx: ^ui.Context, item: ^Album_Item, index: ui.Item_Index) {
	album := &state.player.albums[item.album_index]

	pos := _album_item_pos(index)

	rect: Rect
	rect.x = ctx.box.x + pos.x
	rect.y = ctx.box.y + pos.y - i32(ctx.box.scroll)
	rect.width = self.list.item_width
	rect.height = self.list.item_height

	ui.begin_box(ctx, rect, GAP)

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
		ui.begin_box(ctx, box)

		pos := rect_pos(ctx.box)
		pos.y += ctx.font_height
		pos.y += ctx.box.height / 2 - ctx.font_height / 2

		name := mpd.album_name(album^)
		ui.draw_text(ctx, name, pos, state.theme.black)
	}
}

_album_ui_clear_list :: proc() {
	for &item in self.list.items do album_item_destroy(&item)
	clear(&self.list.items)
}

_album_item_pos :: proc(index: ui.Item_Index) -> Vec2 {
	v: Vec2
	v.x = (index % self.list.columns) * ALBUM_WIDTH
	v.y = (index / self.list.columns) * ALBUM_HEIGHT
	return v
}
