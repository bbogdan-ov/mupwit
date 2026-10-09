//
// Current song queue screen. "Song queue" is also referred as "playlist" in MPD.
//

package mupwit

import "core:log"
import "core:sort"
import "lib:mpd"
import "lib:ui"

Song_Item :: struct {
	using item:  ui.Item,
	float_tween: ui.Tween(f32),
	float:       f32,
	song_index:  mpd.Song_Index,
	loader:      Cover_Loader,
}

Song_Item_List :: ui.Item_List(Song_Item)

@(private = "file")
self: struct {
	list:                Song_Item_List,
	box:                 ui.Box,
	scroll:              ui.Scroll,
	list_just_reordered: bool,
}

queue_ui_init :: proc() {
	ui.item_list_init(&self.list, SONG_HEIGHT, context.allocator)
	self.list.kind = .Reorderable
	self.list.scroll_padding = SONG_HEIGHT

	self.list.item_init = _song_item_init
	self.list.item_destroy = _song_item_destroy
	self.list.item_update = _song_item_update
	self.list.item_search_score = _song_item_search_score
	self.list.on_item_reordered = _queue_ui_on_item_reordered
	self.list.on_item_start_reordering = _queue_ui_on_item_start_reordering
	self.list.on_item_stop_reordering = _queue_ui_on_item_stop_reordering
}

queue_ui_destroy :: proc() {
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

_queue_ui_remove_item :: proc(index: ui.Item_Index) {
	item := &self.list.items[index]
	_song_item_destroy(item)
	ordered_remove(&self.list.items, int(index))

	for i in index ..< ui.items_count(&self.list) {
		item := &self.list.items[i]
		item.song_index = mpd.Song_Index(i)
		ui.item_tween_to_rest(&self.list, item, i)
	}
}

_queue_ui_contents_height :: proc() -> i32 {
	return ui.item_list_content_height(&self.list) + self.list.item_height
}

queue_ui_draw :: proc(state: ^State, ctx: ^ui.Context) {
	if !screen_is_visible(state, .Queue) do return

	box := ui.pad_b(ctx.box, status_ui_visible_height() + clippy_ui_visible_height())
	box.x += screen_x_offset(state, .Queue)
	ui.guard_box(ctx, box, GAP, self.scroll.offset)
	self.box = ctx.box

	if ui.items_count(&self.list) == 0 {
		draw_screen_art(state, ctx)
		return
	}

	from, to := ui.item_list_visible_range(ctx.box, &self.list)
	for i in from ..< to {
		index := ui.Item_Index(i)
		if ui.item_is_reodering(&self.list, index) do continue
		item := &self.list.items[index]
		_song_item_draw(state, ctx, item, index)
	}

	// Draw the currently reordering item above others.
	if self.list.reorder_state != .None {
		index := self.list.reordering
		item := &self.list.items[index]
		_song_item_draw(state, ctx, item, index)
	}

	contents := _queue_ui_contents_height()
	scroll_draw(state, ctx, &self.scroll, contents)
}

// ------------------------------
// Listeners.
// ------------------------------

queue_ui_on_screen_updated :: proc(state: ^State) {
	ui.item_list_stop_reordering(&self.list)

	if state.screen != .Queue do return

	clippy_ui_allow_search(.Queue, self.list.search)

	if state.player.cur_song != nil {
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
}

queue_ui_on_search :: proc(state: ^State, search: string) {
	if state.screen != .Queue do return

	ui.item_list_on_search(&self.list, search, context.allocator)
}

queue_ui_on_scroll :: proc(state: ^State, scroll: f32, touchpad: bool) {
	if state.screen != .Queue do return

	ui.scroll_on_scroll(&self.scroll, scroll, touchpad)
}

queue_ui_on_keyboard_key :: proc(state: ^State, ev: Key_Event) -> (propagate: bool) {
	if state.screen != .Queue do return true

	self.list.userdata = state
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
	ui.item_list_rebuild(&self.list, len(state.player.queue))
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

	ui.item_list_cancel_reordering(&self.list)

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

	shift := ui.Item_Index(sort.compare_i32s(to, from))

	for i in start ..= end {
		index := ui.Item_Index(i)
		item := &self.list.items[index]

		// Animate items reordering.
		if index == to {
			ui.item_tween_from_to(&self.list, item, from, to)
		} else {
			ui.item_tween_from_to(&self.list, item, index + shift, index)
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

_queue_ui_on_item_reordered :: proc(
	list: ^Song_Item_List,
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

_queue_ui_on_item_start_reordering :: proc(
	list: ^Song_Item_List,
	item: ^Song_Item,
	index: ui.Item_Index,
) {
	if ui.controls() == .Keyboard {
		ui.play(&item.float_tween, item.float, ui.ITEM_ANIM_DURATION)
		item.float = 1
	}
}

_queue_ui_on_item_stop_reordering :: proc(
	list: ^Song_Item_List,
	item: ^Song_Item,
	index: ui.Item_Index,
) {
	ui.play(&item.float_tween, item.float, ui.ITEM_ANIM_DURATION)
	item.float = 0
}

// ------------------------------
// Song item.
// ------------------------------

_song_item_init :: proc(list: ^Song_Item_List, item: ^Song_Item, index, number: ui.Item_Index) {
	item.song_index = mpd.Song_Index(index)
}

_song_item_destroy :: proc(item: ^Song_Item) {
	cover_maybe_unref(item.loader.cover)
}

_song_item_update :: proc(
	list: ^Song_Item_List,
	item: ^Song_Item,
	index: ui.Item_Index,
	dt: Seconds,
) {
	if !SONG_LOAD_COVER do return

	state := cast(^State)list.userdata

	ui.tween_update(&item.float_tween, dt)

	is_in_view := ui.item_within_view(self.box, item.position.y, self.list.item_height)
	song := &state.player.queue[item.song_index]

	cover_loader_update(state.player, &item.loader, song.file, song.album, .Small, is_in_view, dt)
}

_song_item_search_score :: proc(list: ^Song_Item_List, item: ^Song_Item) -> i32 {
	state := cast(^State)list.userdata
	song := &state.player.queue[item.song_index]
	return ui.item_list_calc_score(list, song.title)
}

_song_item_draw :: proc(state: ^State, ctx: ^ui.Context, item: ^Song_Item, index: ui.Item_Index) {
	song := &state.player.queue[item.song_index]

	is_mathing := self.list.pattern != nil && item.score >= ui.MIN_SEARCH_SCORE

	pos := item.cur_position

	{
		p := ui.tween_ease(&item.float_tween, item.float, .Cubic_Out)
		pos.x += i32(GAP * 2 * p)
	}

	rect := ctx.box.rect
	rect.x += pos.x
	rect.y += pos.y - ctx.box.scroll
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

	ui.guard_box(ctx, rect, GAP)

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
		ui.guard_box(ctx, box)

		pos := rect_pos(ctx.box)
		pos.x += SONG_COVER_SIZE + GAP
		pos.y += ctx.font_height - 1
		pos.y += ctx.box.height / 2 - (ctx.font_height * 2 + GAP / 2) / 2

		adv := ui.draw_text(ctx, song.title, pos, state.theme.black, bold = is_mathing)
		if is_mathing {
			rect := Rect{pos.x, pos.y + 2, adv.x, 1}
			ui.draw_line_h(ctx, rect, state.theme.black)
		}

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
