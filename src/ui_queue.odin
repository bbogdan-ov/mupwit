//
// Current song queue screen. "Song queue" is also referred as "playlist" in MPD.
//

package mupwit

import "lib:mpd"
import win "lib:my_window"
import "lib:ui"

Song_Item :: struct {
	using item: ui.Item,
	song_index: mpd.Song_Index,
	loader:     Cover_Loader,
	is_in_view: bool,
}

@(private = "file")
self: struct {
	list:   ui.Item_List(Song_Item),
	box:    ui.Box,
	scroll: ui.Scroll,
}

queue_ui_init :: proc() {
	self.list = ui.item_list_make(Song_Item, SONG_HEIGHT, context.allocator)
	self.list.item_update = song_item_update
}

queue_ui_destroy :: proc() {
	_queue_ui_clear_list()
	ui.item_list_destroy(&self.list)
}

queue_ui_update :: proc(state: ^State, dt: Seconds) {
	if state.screen != .Queue do return

	self.list.userdata = state
	ui.item_list_update(&self.box, &self.scroll, &self.list, dt)

	if self.list.just_reordered {
		from := mpd.Song_Index(self.list.reorder.from)
		to := mpd.Song_Index(self.list.reorder.to)
		player_reorder_song(&state.player, from, to)
	}

	if ui.is_clicked(.Left) {
		_queue_ui_play_hovered_song(state)
	} else if ui.state.dragging == nil && ui.is_mouse_double_pressed(.Right) {
		_queue_ui_remove_hovered_song(state)
	}
}

_queue_ui_play_hovered_song :: proc(state: ^State) -> bool {
	hovering := self.list.hovering.? or_return
	item := &self.list.items[hovering]
	player_play_song(&state.player, item.song_index)
	return true
}

_queue_ui_remove_hovered_song :: proc(state: ^State) -> bool {
	hovering := self.list.hovering.? or_return
	item := &self.list.items[hovering]
	player_remove_song(&state.player, item.song_index)
	return true
}

_queue_ui_scroll_to_cur_song :: proc(state: ^State) -> bool {
	index := state.player.cur_song.? or_return
	item := &self.list.items[index]
	off := item.position - self.list.item_height
	ui.scroll_to(self.box, &self.scroll, f32(off))
	return true
}

queue_ui_draw :: proc(state: ^State, ctx: ^ui.Context) {
	if !screen_is_visible(state, .Queue) do return

	box := ui.pad_b(ctx.box, status_ui_visible_height())
	box.x += screen_x_offset(state, .Queue)
	ui.begin_box(ctx, box, GAP, self.scroll.offset)
	self.box = ctx.box

	// Draw a little "empty" symbol.
	if len(self.list.items) == 0 {
		pos := rect_center(ctx.box)
		pos.y += ctx.font_height / 2
		ui.draw_text(ctx, "❦", pos, state.theme.gray, align = .Center)
		return
	}

	from, to := ui.item_list_visible_range(ctx.box, &self.list)
	for i in from ..< to {
		if self.list.reordering == ui.Item_Index(i) do continue
		item := &self.list.items[i]
		song_item_draw(state, ctx, item)
	}

	// Draw the currently reordering item above others.
	reordering, has_reordering := self.list.reordering.?
	if has_reordering {
		item := &self.list.items[reordering]
		song_item_draw(state, ctx, item)
	}

	length := _queue_ui_contents_length()
	scroll_draw(state, ctx, &self.scroll, length)
}

_queue_ui_contents_length :: proc() -> i32 {
	length := i32(len(self.list.items)) * self.list.item_height
	length += self.list.item_height
	return length
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

	for i in index ..< ui.Item_Index(len(self.list.items)) {
		item := &self.list.items[i]
		item.song_index = mpd.Song_Index(i)
		ui.item_tween_to_rest(item, i, self.list.item_height)
	}
}

queue_ui_on_screen_updated :: proc(state: ^State) {
	if state.screen != .Queue do return

	index, has_song := state.player.cur_song.?
	if !has_song do return

	// FIXME: this is a crutch, should be a better and automated way to update
	// scroll content length, but it'll work for now.
	// The problem with this solution is that `self.box` may be empty (i.e.
	// width and height are zeros) when calling `scroll_set` and the content
	// length may be larger that it should be because of that.
	length := _queue_ui_contents_length()
	ui.scroll_update_max_offset(self.box, &self.scroll, length)

	off := i32(index - 1) * self.list.item_height
	ui.scroll_set(&self.scroll, f32(off))
}

queue_ui_on_scroll :: proc(state: ^State, scroll: f32, touchpad: bool) {
	if state.screen != .Queue do return

	ui.scroll_on_scroll(&self.scroll, scroll, touchpad)
}

queue_ui_on_keyboard_key :: proc(state: ^State, key: win.Key, mods: win.Mods) {
	if state.screen != .Queue do return

	shift := .Shift in mods

	switch {
	case key == .Z:
		_queue_ui_scroll_to_cur_song(state)

	case key == .G && shift, key == .End:
		ui.scroll_to(self.box, &self.scroll, self.scroll.max_offset)
	case key == .G, key == .Home:
		ui.scroll_to(self.box, &self.scroll, 0)
	}
}

queue_ui_on_queue_updated :: proc(state: ^State) {
	player := &state.player

	ui.item_list_stop_reodering(&self.list)

	_queue_ui_clear_list()
	non_zero_reserve(&self.list.items, len(player.queue))

	for _, index in player.queue {
		item := Song_Item {
			position   = i32(index) * self.list.item_height,
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
		if !ui.item_within_box(self.box, prev.position, height) do return
	}

	ui.item_list_scroll_to(self.box, &self.scroll, &self.list, ui.Item_Index(index))
}

queue_ui_on_song_reordered :: proc(from, to: mpd.Song_Index) {
	start, end := ui.range_unflip(from, to)
	for i in start ..= end {
		item := &self.list.items[i]
		item.song_index = mpd.Song_Index(i)
	}
}

queue_ui_on_song_removed :: proc(index: mpd.Song_Index) {
	_queue_ui_remove_item(ui.Item_Index(index))
}

song_item_destroy :: proc(item: ^Song_Item) {
	if cover, ok := item.loader.cover.?; ok {
		cover_unref(cover)
		item.loader.cover = nil
	}
}

song_item_update :: proc(
	list: ^ui.Item_List(Song_Item),
	item: ^Song_Item,
	index: ui.Item_Index,
	dt: Seconds,
) {
	if !SONG_LOAD_COVER do return

	state := cast(^State)list.userdata

	request := cover_loader_update(&item.loader, item.is_in_view, dt)
	if request {
		song := &state.player.queue[item.song_index]
		cover := cover_get_or_request(&state.player, song.file, song.album, .Small)
		item.loader.cover = cover_ref(cover)
	}

	item.is_in_view = false
}

song_item_draw :: proc(state: ^State, ctx: ^ui.Context, item: ^Song_Item) {
	song := &state.player.queue[item.song_index]
	item.is_in_view = true

	pos := ui.item_tweened_pos(item)
	rect := ui.item_rect(ctx.box, pos, self.list.item_height)

	if item.is_hovering {
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
