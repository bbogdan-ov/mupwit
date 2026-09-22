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
}

@(private = "file")
self: struct {
	list:   ui.Item_List(Song_Item),
	box:    ui.Box,
	scroll: ui.Scroll,
}

queue_ui_init :: proc() {
	self.list.item_height = SONG_HEIGHT
}

queue_ui_update :: proc(state: ^State, dt: Seconds) {
	if state.screen != .Queue do return

	ui.scroll_update(&self.box, &self.scroll, dt)

	ui.item_list_update(self.box, &self.list, dt)

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
	if state.screen != .Queue do return

	player := &state.player

	box := ui.pad_b(ctx.box, STATUS_HEIGHT)
	box.y += screen_y_offset(state)
	ui.begin_box(ctx, box, GAP, self.scroll.offset)
	self.box = ctx.box

	from, to := ui.item_list_visible_range(ctx.box, &self.list)
	for i in from ..< to {
		item := &self.list.items[i]
		song_item_draw(state, ctx, item)
	}

	contents := i32(len(player.queue)) * self.list.item_height
	ui.scroll_draw(ctx, &self.scroll, contents, LIGHT_GRAY, GRAY)
}

queue_ui_on_scroll :: proc(state: ^State, scroll: f32, touchpad: bool) {
	if state.screen != .Queue do return

	ui.scroll_on_scroll(&self.scroll, scroll, touchpad)
}

queue_ui_on_received_queue :: proc(state: ^State) {
	player := &state.player

	clear(&self.list.items)
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

song_item_draw :: proc(state: ^State, ctx: ^ui.Context, item: ^Song_Item) {
	song := &state.player.queue[item.song_index]

	pos := ui.item_tweened_pos(item)
	rect := ui.item_rect(ctx.box, pos, self.list.item_height)

	if item.is_hovering {
		ui.draw_box_rounded(ctx, rect, LIGHT_GRAY, filled = true)
	}

	// Draw "current marker".
	if item.song_index == state.player.cur_song {
		pos := rect_pos(rect) - ICON_SIZE / 2
		pos.y += rect.height / 2
		draw_icon(state, ctx, .Small_Arrow_Right, pos, BLACK)
	}

	ui.begin_box(ctx, rect, GAP)

	// Draw song cover.
	{
		rect := ctx.box
		rect.width = SONG_COVER_SIZE
		rect.height = SONG_COVER_SIZE
		ui.draw_box(ctx, rect, BLACK)
		draw_icon(state, ctx, .Disk, icon_center_inside(rect), BLACK)
	}

	// Draw song duration.
	duration_advance: i32
	{
		pos := rect_pos(ctx.box)
		pos.x += ctx.box.width
		pos.y += ctx.box.height / 2 + ctx.font_height / 2

		adv := ui.draw_text(ctx, song.duration_str, pos, GRAY, align = .End)
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

		ui.draw_text(ctx, song.title, pos, BLACK)
		pos.y += ctx.font_height + GAP / 2
		ui.draw_text(ctx, song.artist, pos, GRAY)
	}
}
