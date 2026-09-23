package mupwit

import "core:fmt"

import "lib:mpd"
import win "lib:my_window"
import "lib:ui"

@(private = "file")
self: struct {
	button_prev:        ui.Button,
	button_play:        ui.Button,
	button_next:        ui.Button,
	slider:             ui.Slider,
	cover_tween:        ui.Tween(f32),
	prev_cover, cover:  Maybe(^Cover),
	loading_cover:      Maybe(^Cover),
	update_cover_timer: Seconds,
}

player_ui_update :: proc(state: ^State, dt: Seconds) {
	if self.update_cover_timer > 0 {
		self.update_cover_timer -= dt

		if self.update_cover_timer <= 0 {
			_player_ui_update_cover(state)
		}
	}

	if cover, ok := self.loading_cover.?; ok {
		if !cover.loading {
			_player_ui_set_cover(cover)
			self.loading_cover = nil
		}
	}

	if state.screen != .Player {
		ui.tween_finish(&self.cover_tween)
		return
	}

	player := &state.player

	ui.tween_update(&self.cover_tween, dt)

	if ui.button_update(&self.button_prev) {
		player_previous(player)
	}
	if ui.button_update(&self.button_play) {
		player_toggle_play(player)
	}
	if ui.button_update(&self.button_next) {
		player_next(player)
	}

	if ui.slider_update(&self.slider) {
		player_seek_percent(player, self.slider.progress)
	}
	if ui.slider_is_dragging(&self.slider) {
		secs := player.duration * Seconds(self.slider.progress)
		player.elapsed = secs
	}
}

player_ui_draw :: proc(state: ^State, ctx: ^ui.Context) {
	if state.screen != .Player do return

	player := &state.player
	song, has_song := player_cur_song(player)

	box := ctx.box
	box.y += screen_y_offset(state)
	ui.begin_box(ctx, box, PLAYER_PADDING)

	offset: Vec2

	// Draw current song cover.
	{
		rect := cover_rect(.Huge, rect_pos(ctx.box))

		dir: i32 = 1
		if player.switch_direction == .Previous {
			dir = -1
		}

		progress := ui.tween_ease(&self.cover_tween, 1, .Cubic_In_Out)
		vw := f32(ui.state.view.width)
		{
			r := rect
			r.x -= i32(vw * progress) * dir
			_player_ui_draw_cover(ctx, self.prev_cover, r)
		}
		{
			r := rect
			r.x += i32(vw * (1 - progress)) * dir
			_player_ui_draw_cover(ctx, self.cover, r)
		}

		offset.y += rect.height
	}

	if has_song {
		offset.y += GAP * 3

		pos := rect_pos(ctx.box) + offset
		height := ctx.font_height * 2 + GAP

		pos.y += ctx.font_height
		pos.y += ICON_BUTTON_SIZE / 2 - height / 2
		ui.draw_text(ctx, song.title, pos, BLACK, bold = true)
		pos.y += ctx.font_height + GAP / 2

		artist := fmt.tprint(song.artist, '-', song.album)
		ui.draw_text(ctx, artist, pos, GRAY)

		offset.y += height
	}

	// Draw slider.
	{
		offset.y += GAP * 3
		ui.begin_box(ctx, ui.pad_t(ctx.box, offset.y))
		offset.y += _player_ui_draw_slider(state, ctx)
	}

	// Draw control buttons.
	{
		btn :: draw_icon_button

		offset.y -= GAP

		rect: Rect
		rect.y = ctx.box.y + offset.y
		rect.width = ICON_BUTTON_SIZE * 3
		rect.height = ICON_BUTTON_SIZE
		rect.x = ctx.box.x + ctx.box.width / 2 - rect.width / 2

		play_icon := icon_from_playstate(player.playstate)

		pos := rect_pos(rect)
		pos.x += btn(state, ctx, &self.button_prev, .Previous, pos, BLACK)
		pos.x += btn(state, ctx, &self.button_play, play_icon, pos, BLACK)
		pos.x += btn(state, ctx, &self.button_next, .Next, pos, BLACK)

		offset.y += rect.height
	}
}

_player_ui_draw_cover :: proc(ctx: ^ui.Context, cover: Maybe(^Cover), rect: Rect) {
	res := cover_draw(ctx, cover, rect_pos(rect))
	#partial switch res {
	case .No_Cover:
		return
	case .No_Surface:
		ui.draw_rect(ctx, rect, GRAY)
	}

	ui.draw_box_bulgy(ctx, ui.pad(rect, -1), BLACK)
}

_player_ui_draw_slider :: proc(state: ^State, ctx: ^ui.Context) -> (height: i32) {
	player := &state.player

	elapsed_str := mpd.format_seconds(mpd.Seconds(player.elapsed), context.temp_allocator)
	duration_str := mpd.format_seconds(mpd.Seconds(player.duration), context.temp_allocator)

	rect := ctx.box.rect
	rect.y += height
	rect.height = ui.SLIDER_THICKNESS

	progress := player_progress(player)
	ui.slider_draw(ctx, &self.slider, progress, rect, BLACK, GRAY)
	height += rect.height

	height += ctx.font_height * 2

	pos := rect_pos(ctx.box)
	pos.y += height
	ui.draw_text(ctx, elapsed_str, pos, GRAY)
	pos.x += ctx.box.width
	ui.draw_text(ctx, duration_str, pos, GRAY, align = .End)
	height += ctx.font_height

	return height
}

player_ui_on_keyboard_key :: proc(state: ^State, key: win.Key, mods: win.Mods) {
	if TEST_COVERS && key == .Enter {
		if .Shift in mods {
			TEST_CUR_FILE = ui.wrap(TEST_CUR_FILE - 1, len(TEST_FILES))
			state.player.switch_direction = .Previous
		} else {
			TEST_CUR_FILE = ui.wrap(TEST_CUR_FILE + 1, len(TEST_FILES))
			state.player.switch_direction = .Next
		}

		item := TEST_FILES[TEST_CUR_FILE]
		album := item[0]
		file := mpd.Song_File(item[1])
		_player_ui_request_cover(&state.player, file, album, .Huge)
	}
}

player_ui_on_cur_song_updated :: proc(state: ^State) {
	if !TEST_COVERS {
		_player_ui_defer_cover_update(state)
	}
}

_player_ui_defer_cover_update :: proc(state: ^State) {
	song, has_song := player_cur_song(&state.player)
	if has_song {
		cover, has_cover := cover_get(&state.player, song.file, song.album, .Huge)
		if has_cover {
			_player_ui_set_cover(cover_ref(cover))
		} else {
			self.update_cover_timer = PLAYER_COVER_UPDATE_DELAY
		}
	} else {
		_player_ui_set_cover(nil)
	}
}

_player_ui_update_cover :: proc(state: ^State) {
	song, has_song := player_cur_song(&state.player)
	if has_song {
		_player_ui_request_cover(&state.player, song.file, song.album, .Huge)
	} else {
		_player_ui_set_cover(nil)
	}
}

_player_ui_request_cover :: proc(
	player: ^Player,
	file: mpd.Song_File,
	album: mpd.Album_Name,
	size: Cover_Size,
) {
	cover := cover_get_or_request(player, file, album, .Huge)
	if cover.loading {
		// Do not set the new cover right away if it is loading. We'll wait
		// for the new cover to load and only then apply it.
		self.loading_cover = cover_ref(cover)
	} else {
		_player_ui_set_cover(cover_ref(cover))
	}
}

_player_ui_set_cover :: proc(cover: Maybe(^Cover)) {
	if prev, ok := self.prev_cover.?; ok {
		assert(prev.ref_count >= 2)
		cover_unref(prev)
	}
	self.prev_cover = self.cover
	self.cover = cover

	ui.tween_play(&self.cover_tween, 0, PLAYER_COVER_ANIM_DURATION)
}

TEST_COVERS :: false
TEST_CUR_FILE: int = 0
TEST_FILES := [?][2]string {
	{`Telepathic Onset`, `Alec Normal/Telepathic Onset/001 One Floor Down.mp3`},
	{`An Awesome Wave`, `alt-J/An Awesome Wave/001 Intro.mp3`},
	{``, `alt-J/other/353.mp3`},
	{`AMOK`, `Atoms For Peace/AMOK/001 Before Your Very Eyes....mp3`},
	{
		`Minecraft – Volume Beta`,
		`C418/Minecraft - Volume Beta/C418 - Minecraft - Volume Beta - 01-01 Ki.flac`,
	},
	{`Viator`, `Jack Stauber/Viator/001 On.mp3`},
	{`0`, `Low Roar/0/001 Breathe In.flac`},
	{`0`, `Low Roar/0/002 Easy Way Out.flac`},
	{`Com Lag: 2+2=5`, `Radiohead/Com Lag: 2+2=5/002 I Am a Wicked Child.mp3`},
	{`Currents`, `Tame Impala/Currents/001 Let It Happen.mp3`},
	{
		`A Light for Attracting Attention`,
		`The Smile/A Light for Attracting Attention/000 The Same.mp3`,
	},
	{`ANIMA`, `Thom Yorke/ANIMA/001 Traffic.mp3`},
	{`The Eraser`, `Thom Yorke/The Eraser/001 The Eraser.mp3`},
	{`LOST SONGS VOL. 4: 2003-2021`, `Whitey/LOST SONGS VOL. 4: 2003-2021/001 DRAG IT OUT.mp3`},
	{``, `Alec Normal/other/Breakaway.mp3`},
}
