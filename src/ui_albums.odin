package mupwit

import "lib:mpd"
import "lib:ui"

Album_Item :: struct {
	album_index: mpd.Album_Index,
	loader:      Cover_Loader,
	is_in_view:  bool,
}

@(private = "file")
self: struct {
	items:          [dynamic]Album_Item,
	scroll:         ui.Scroll,
	box:            ui.Box,
	hovering_index: Maybe(ui.Item_Index),
}

albums_ui_init :: proc() {
	self.items = make([dynamic]Album_Item, context.allocator)
}

albums_ui_destroy :: proc() {
	_album_ui_clear_list()
	delete(self.items)
	self.items = nil
}

albums_ui_update :: proc(state: ^State, dt: Seconds) {
	if state.screen != .Albums do return

	ui.scroll_update(&self.box, &self.scroll, dt)

	if ui.is_hovering(self.box) {
		pos := ui.rel_pointer(self.box)
		pos.y /= ALBUM_HEIGHT
		pos.y *= ALBUM_GRID_COLUMS
		pos.x /= ALBUM_WIDTH
		index: ui.Item_Index = pos.y + pos.x
		if within(index, 0, i32(len(self.items))) {
			self.hovering_index = index
		} else {
			self.hovering_index = nil
		}
	} else {
		self.hovering_index = nil
	}

	for &item in self.items {
		album_item_update(state, &item, dt)
	}

	if self.hovering_index != nil {
		ui.set_cursor(.Pointer)
	}
}

albums_ui_draw :: proc(state: ^State, ctx: ^ui.Context) {
	if !screen_is_visible(state, .Albums) do return

	box := ui.pad_b(ctx.box, status_ui_visible_height())
	box.x += screen_x_offset(state, .Albums)
	ui.begin_box(ctx, box, GAP, self.scroll.offset)
	self.box = ctx.box

	rows := _album_ui_rows()
	from, to := ui.scroll_visible_range(ctx.box, rows, ALBUM_HEIGHT)
	from *= ALBUM_GRID_COLUMS
	to = min(to * ALBUM_GRID_COLUMS, len(self.items))
	for i in from ..< to {
		if i >= len(self.items) do break

		index := ui.Item_Index(i)
		item := &self.items[index]
		album_item_draw(state, ctx, item, index)
	}

	length := _album_ui_content_length()
	scroll_draw(state, ctx, &self.scroll, length)
}

albums_ui_on_scroll :: proc(state: ^State, scroll: f32, touchpad: bool) {
	if state.screen != .Albums do return

	ui.scroll_on_scroll(&self.scroll, scroll, touchpad)
}

albums_ui_on_album_list_updated :: proc(state: ^State) {
	_album_ui_clear_list()
	non_zero_reserve(&self.items, len(state.player.albums))

	for _, i in state.player.albums {
		item := Album_Item {
			album_index = mpd.Album_Index(i),
		}
		append(&self.items, item)
	}
}

album_item_destroy :: proc(item: ^Album_Item) {
	if cover, ok := item.loader.cover.?; ok {
		cover_unref(cover)
		item.loader.cover = nil
	}
}

album_item_update :: proc(state: ^State, item: ^Album_Item, dt: Seconds) {
	request := cover_loader_update(&item.loader, item.is_in_view, dt)
	if request {
		album := state.player.albums[item.album_index]
		song := mpd.album_first_song(album)

		cover := cover_get_or_request(&state.player, song.file, song.album, .Medium)
		item.loader.cover = cover_ref(cover)
	}

	item.is_in_view = false
}

album_item_draw :: proc(state: ^State, ctx: ^ui.Context, item: ^Album_Item, index: ui.Item_Index) {
	album := &state.player.albums[item.album_index]
	item.is_in_view = true

	rect: Rect
	rect.x = ctx.box.x + (index % ALBUM_GRID_COLUMS) * ALBUM_WIDTH
	rect.y = ctx.box.y + (index / ALBUM_GRID_COLUMS) * ALBUM_HEIGHT - i32(ctx.box.scroll)
	rect.width = ALBUM_WIDTH
	rect.height = ALBUM_HEIGHT

	ui.begin_box(ctx, rect, GAP)

	if self.hovering_index == index {
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
	for &item in self.items do album_item_destroy(&item)
	clear(&self.items)
}

_album_ui_content_length :: proc() -> i32 {
	rows := _album_ui_rows()
	return i32(rows) / ALBUM_GRID_COLUMS * ALBUM_HEIGHT
}

_album_ui_rows :: proc() -> int {
	count := len(self.items)
	count += count % ALBUM_GRID_COLUMS
	return count
}
