//
// Current song queue screen. "Song queue" is also referred as "playlist" in MPD.
//

package mupwit

import "core:log"
import "lib:mpd"
import "lib:ui"

Song_Item :: struct {
	using item: ui.Item,
	song_index: mpd.Song_Index,
	cover:      Maybe(^Cover),
}

@(private = "file")
self: struct {
	list:   ui.Item_List(Song_Item),
	box:    ui.Box,
	scroll: ui.Scroll,
}

queue_ui_init :: proc() {
	self.list = ui.item_list_make(Song_Item, SONG_HEIGHT, context.allocator)
}

queue_ui_destroy :: proc() {
	_queue_ui_clear_list()
	ui.item_list_destroy(&self.list)
}

queue_ui_update :: proc(state: ^State, dt: Seconds) {
	if state.screen != .Queue do return

	ui.item_list_update(&self.box, &self.scroll, &self.list, dt)

	if self.list.just_reordered {
		from := mpd.Song_Index(self.list.reorder.from)
		to := mpd.Song_Index(self.list.reorder.to)
		player_reorder_song(&state.player, from, to)
		state.player.ignore_next_queue_update = true
	}

	if ui.is_clicked(.Left) {
		_queue_ui_play_hovered_song(state)
	}
}

_queue_ui_play_hovered_song :: proc(state: ^State) -> bool {
	hovering := self.list.hovering.? or_return

	item := &self.list.items[hovering]
	song := &state.player.queue[item.song_index]

	// TEMPORARY:
	log.info("Play", song.title, "-", song.artist)
	// player_play_song(item.song_index)

	return true
}

queue_ui_draw :: proc(state: ^State, ctx: ^ui.Context) {
	if !screen_is_visible(state, .Queue) do return

	box := ui.pad_b(ctx.box, STATUS_HEIGHT + QUEUE_STATUS_HEIGHT)
	box.x += screen_x_offset(state, .Queue)
	ui.begin_box(ctx, box, GAP, self.scroll.offset)
	self.box = ctx.box

	// TODO: show "queue is empty" when needed.
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

	// TODO: should also scroll to the current song when it is out of the view.
	off := i32(index - 1) * self.list.item_height
	ui.scroll_set(&self.scroll, f32(off))
}

queue_ui_on_scroll :: proc(state: ^State, scroll: f32, touchpad: bool) {
	if state.screen != .Queue do return

	ui.scroll_on_scroll(&self.scroll, scroll, touchpad)
}

queue_ui_on_received_queue :: proc(state: ^State) {
	player := &state.player

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

queue_ui_on_song_reordered :: proc(from, to: mpd.Song_Index) {
	start, end := ui.range_unflip(from, to)
	for i in start ..= end {
		item := &self.list.items[i]
		item.song_index = mpd.Song_Index(i)
	}
}

song_item_destroy :: proc(item: ^Song_Item) {
	if cover, ok := item.cover.?; ok {
		cover_unref(cover)
		item.cover = nil
	}
}

song_item_draw :: proc(state: ^State, ctx: ^ui.Context, item: ^Song_Item) {
	song := &state.player.queue[item.song_index]

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
		if SONG_LOAD_COVER && item.cover == nil {
			cover := cover_get_or_request(&state.player, song.file, song.album, .Small)
			item.cover = cover_ref(cover)
		}

		rect := ctx.box
		rect.width = SONG_COVER_SIZE
		rect.height = SONG_COVER_SIZE

		res := Cover_Draw_Result.No_Cover
		if SONG_LOAD_COVER {
			res = cover_draw(ctx, item.cover, rect_pos(rect))
		}
		if res != .Drawn {
			draw_icon(state, ctx, .Disk, icon_center_inside(rect), state.theme.black)
		}

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
