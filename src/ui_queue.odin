//
// Current song queue screen. "Song queue" is also referred as "playlist" in MPD.
//

package mupwit

import "core:log"
import "core:sort"
import "lib:mpd"
import "lib:ui"

Song_Item :: struct {
	using item: ui.Item,
	song_index: mpd.Song_Index,
	loader:     Cover_Loader,
}

@(private = "file")
self: struct {
	list:                ui.Item_List(Song_Item),
	box:                 ui.Box,
	scroll:              ui.Scroll,
	list_just_reordered: bool,
}

queue_ui_init :: proc() {
	ui.item_list_init(&self.list, SONG_HEIGHT, context.allocator)
	self.list.reorderable = true
	self.list.scroll_padding = SONG_HEIGHT
	self.list.item_update = queue_ui_list_item_update
	self.list.on_item_reordered = queue_ui_list_on_item_reordered
	self.list.on_item_start_reordering = queue_ui_list_on_item_start_reordering
	self.list.on_item_stop_reordering = queue_ui_list_on_item_stop_reordering
}

queue_ui_destroy :: proc() {
	_queue_ui_clear_list()
	ui.item_list_destroy(&self.list)
}

queue_ui_update :: proc(state: ^State, dt: Seconds) {
	if state.screen != .Queue do return

	self.list.userdata = state
	ui.item_list_update(&self.box, &self.scroll, &self.list, dt)

	if ui.is_clicked(.Left) {
		_queue_ui_play_hovered_song(state)
	} else if ui.is_double_clicked(.Right) {
		_queue_ui_remove_hovered_song(state)
	}
}

_queue_ui_play_hovered_song :: proc(state: ^State) -> bool {
	hovering := self.list.hovering.? or_return
	item := &self.list.items[hovering]
	player_queue_play(state.player, item.song_index)
	return true
}

_queue_ui_remove_hovered_song :: proc(state: ^State) -> bool {
	ui.item_list_stop_reordering(&self.list)

	hovering := self.list.hovering.? or_return
	item := &self.list.items[hovering]
	player_queue_remove(state.player, item.song_index)
	return true
}

_queue_ui_scroll_to_cur_song :: proc(state: ^State, smooth := true) -> bool {
	song_index := state.player.cur_song.? or_return
	index := ui.Item_Index(song_index)

	item := &self.list.items[index]
	off := item.position.y - self.list.item_height

	if ui.controls() != .Keyboard {
		ui.item_list_set_hovering(&self.list, index)
		ui.scroll_to(self.box, &self.scroll, f32(off), smooth = smooth)
	} else {
		ui.item_list_set_cursor(self.box, &self.scroll, &self.list, {0, index})
		if self.list.reorder_state != .Active {
			ui.scroll_to(self.box, &self.scroll, f32(off), smooth = smooth)
		}
	}

	return true
}

_queue_ui_clear_list :: proc() {
	for &item in self.list.items {
		song_item_destroy(&item)
	}
	clear(&self.list.items)
}

_queue_ui_remove_item :: proc(index: ui.Item_Index) {
	item := &self.list.items[index]
	song_item_destroy(item)
	ordered_remove(&self.list.items, int(index))

	for i in index ..< ui.items_count(&self.list) {
		item := &self.list.items[i]
		item.song_index = mpd.Song_Index(i)
		ui.item_tween_to_rest(item, i, self.list.item_height)
	}
}

queue_ui_draw :: proc(state: ^State, ctx: ^ui.Context) {
	if !screen_is_visible(state, .Queue) do return

	box := ui.pad_b(ctx.box, status_ui_visible_height())
	box.x += screen_x_offset(state, .Queue)
	ui.begin_box(ctx, box, GAP, self.scroll.offset)
	self.box = ctx.box

	// Draw a little "empty" symbol.
	if ui.items_count(&self.list) == 0 {
		pos := rect_center(ctx.box)
		pos.y += ctx.font_height / 2
		ui.draw_text(ctx, "❦", pos, state.theme.gray, align = .Center)
		return
	}

	from, to := ui.item_list_visible_range(ctx.box, &self.list)
	for i in from ..< to {
		index := ui.Item_Index(i)
		if ui.item_is_reodering(&self.list, index) do continue
		item := &self.list.items[index]
		song_item_draw(state, ctx, item, index)
	}

	// Draw the currently reordering item above others.
	if self.list.reorder_state != .None {
		index := self.list.reordering
		item := &self.list.items[index]
		song_item_draw(state, ctx, item, index)
	}

	contents := _queue_ui_contents_height()
	scroll_draw(state, ctx, &self.scroll, contents)
}

_queue_ui_contents_height :: proc() -> i32 {
	return ui.item_list_content_height(&self.list) + self.list.item_height
}

queue_ui_on_screen_updated :: proc(state: ^State) {
	ui.item_list_stop_reordering(&self.list)

	if state.screen != .Queue do return

	if state.player.cur_song == nil do return

	// FIXME: this is a crutch, should be a better and automated way to update
	// scroll content length, but it'll work for now.
	// The problem with this solution is that `self.box` may be empty (i.e.
	// width and height are zeros) when calling `scroll_set` and the content
	// length may be larger that it should be because of that.
	if self.box.height <= 0 {
		self.box.height = ui.state.view.height - GAP * 2 - STATUS_MAX_HEIGHT
	}
	contents := _queue_ui_contents_height()
	ui.scroll_update_length(self.box, &self.scroll, contents)

	_queue_ui_scroll_to_cur_song(state, smooth = false)
}

queue_ui_on_scroll :: proc(state: ^State, scroll: f32, touchpad: bool) {
	if state.screen != .Queue do return

	ui.scroll_on_scroll(&self.scroll, scroll, touchpad)
}

queue_ui_on_keyboard_key :: proc(state: ^State, ev: Key_Event) -> (propagate: bool) {
	if state.screen != .Queue do return true

	ui.item_list_on_keyboard_key(self.box, &self.scroll, &self.list, ev) or_return

	switch {
	case is_key(ev, .Z):
		_queue_ui_scroll_to_cur_song(state)

	case is_key(ev, .Enter), is_ctrl_key(ev, .J):
		if ui.controls() != .Keyboard do break
		_queue_ui_play_hovered_song(state)
	case is_key(ev, .D):
		if ui.controls() != .Keyboard do break
		_queue_ui_remove_hovered_song(state)

	case:
		propagate = true
	}

	return propagate
}

queue_ui_on_queue_updated :: proc(state: ^State) {
	player := state.player

	ui.item_list_cancel_reordering(&self.list)

	_queue_ui_clear_list()
	non_zero_reserve(&self.list.items, len(player.queue))

	for _, index in player.queue {
		item := Song_Item {
			item       = ui.item_make(&self.list, ui.Item_Index(index)),
			song_index = mpd.Song_Index(index),
		}
		append(&self.list.items, item)
	}
}

queue_ui_on_cur_song_updated :: proc(state: ^State, prev_index: Maybe(mpd.Song_Index)) {
	index, ok := state.player.cur_song.?
	if !ok do return

	if prev_index, ok := prev_index.?; ok {
		// Scroll only to a song that was visible before.
		prev := &self.list.items[prev_index]
		height := self.list.item_height
		if !ui.item_within_box(self.box, prev.position.y, height) do return
	}

	// FIXME!: it doesn't scroll to the current song when the queue changes and
	// the new current song is outside of the view.
	ui.item_list_scroll_to(self.box, &self.scroll, &self.list, ui.Item_Index(index))
}

queue_ui_on_song_reordered :: proc(state: ^State, from, to: mpd.Song_Index) {
	from, to := ui.Item_Index(from), ui.Item_Index(to)

	log.debugf("UI QUEUE: Song reordered: %v -> %v", from, to)

	start, end := ui.range_sort(from, to)
	if self.list_just_reordered {
		self.list_just_reordered = false
		for i in start ..= end {
			item := &self.list.items[i]
			item.song_index = mpd.Song_Index(i)
		}

		// Animate items reordering only if they were not reordered by dragging
		// items in the list.
		return
	}

	ui.item_list_cancel_reordering(&self.list)

	shift := ui.Item_Index(sort.compare_i32s(to, from))

	for i in start ..= end {
		index := ui.Item_Index(i)
		item := &self.list.items[index]

		// Animate items reordering.
		if index == to {
			ui.item_tween_from_to(item, from, to, self.list.item_height)
		} else {
			ui.item_tween_from_to(item, index + shift, index, self.list.item_height)
		}

		item.song_index = mpd.Song_Index(index)
		// NOTE: reset the cover so it can be requested on the next frame.
		cover_maybe_unref(item.loader.cover)
		item.loader.cover = nil
	}

	if hovering, ok := self.list.hovering.?; ok {
		self.list.hovering = ui.shifted_index(hovering, from, to)
	}
}

queue_ui_on_song_removed :: proc(index: mpd.Song_Index) {
	ui.item_list_cancel_reordering(&self.list)
	_queue_ui_remove_item(ui.Item_Index(index))
}

queue_ui_list_item_update :: proc(
	list: ^ui.Item_List(Song_Item),
	item: ^Song_Item,
	index: ui.Item_Index,
	dt: Seconds,
) {
	if !SONG_LOAD_COVER do return

	state := cast(^State)list.userdata

	is_in_view := ui.item_within_view(self.box, item.position.y, self.list.item_height)
	song := &state.player.queue[item.song_index]

	cover_loader_update(state.player, &item.loader, song.file, song.album, .Small, is_in_view, dt)
}

queue_ui_list_on_item_reordered :: proc(
	list: ^ui.Item_List(Song_Item),
	item: ^Song_Item,
	index: ui.Item_Index,
	reorder: ui.Item_Reorder,
) {
	state := cast(^State)list.userdata

	self.list_just_reordered = true

	from := mpd.Song_Index(reorder.from)
	to := mpd.Song_Index(reorder.to)
	player_queue_reorder(state.player, from, to)
}

queue_ui_list_on_item_start_reordering :: proc(
	list: ^ui.Item_List(Song_Item),
	item: ^Song_Item,
	index: ui.Item_Index,
) {
	if ui.controls() == .Keyboard {
		item.position.x = GAP * 2
	}
}

queue_ui_list_on_item_stop_reordering :: proc(
	list: ^ui.Item_List(Song_Item),
	item: ^Song_Item,
	index: ui.Item_Index,
) {
	item.position.x = 0
}

song_item_destroy :: proc(item: ^Song_Item) {
	cover_maybe_unref(item.loader.cover)
}

song_item_draw :: proc(state: ^State, ctx: ^ui.Context, item: ^Song_Item, index: ui.Item_Index) {
	song := &state.player.queue[item.song_index]

	pos := item.cur_position
	rect := ctx.box.rect
	rect.x += pos.x
	rect.y += pos.y - i32(ctx.box.scroll)
	rect.width -= pos.x
	rect.height = self.list.item_height

	if self.list.hovering == index {
		ui.draw_box_rounded(ctx, rect, state.theme.light_gray, filled = true)
	}

	// Draw "current marker".
	if item.song_index == state.player.cur_song {
		pos := rect_pos(rect) - ICON_SIZE / 2
		pos.y += rect.height / 2
		draw_icon(state, ctx, .Small_Arrow_Right, pos, state.theme.black)
	}

	ui.begin_box(ctx, rect, GAP)

	// Draw song cover.
	{
		rect := ctx.box
		rect.width = SONG_COVER_SIZE
		rect.height = SONG_COVER_SIZE

		_song_item_draw_cover(state, ctx, &item.loader, rect)
		ui.draw_box(ctx, ui.pad(rect, -1), state.theme.black)
	}

	// Draw song duration.
	duration_advance: i32
	{
		pos := rect_pos(ctx.box)
		pos.x += ctx.box.width
		pos.y += ctx.box.height / 2 + ctx.font_height / 2

		adv := ui.draw_text(ctx, song.duration_str, pos, state.theme.gray, align = .End)
		duration_advance = adv.x
	}

	// Draw song title and artist.
	{
		box := ctx.box
		box.width += -duration_advance - GAP
		ui.begin_box(ctx, box)

		pos := rect_pos(ctx.box)
		pos.x += SONG_COVER_SIZE + GAP
		pos.y += ctx.font_height - 1
		pos.y += ctx.box.height / 2 - (ctx.font_height * 2 + GAP / 2) / 2

		ui.draw_text(ctx, song.title, pos, state.theme.black)
		pos.y += ctx.font_height + GAP / 2
		ui.draw_text(ctx, song.artist, pos, state.theme.gray)
	}
}

_song_item_draw_cover :: proc(state: ^State, ctx: ^ui.Context, loader: ^Cover_Loader, rect: Rect) {
	if !SONG_LOAD_COVER {
		draw_icon(state, ctx, .Disk, icon_center_inside(rect), state.theme.black)
		return
	}

	alpha := cover_loader_alpha(loader)
	if alpha < 1 {
		draw_icon(state, ctx, .Disk, icon_center_inside(rect), state.theme.black)
	}
	cover_draw(ctx, loader.cover, rect_pos(rect), f64(alpha))
}
