package mupwit

import "core:fmt"
import "core:math/ease"

import "lib:mpd"
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
	_player_ui_update_cover_handling(state, dt)

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

_player_ui_update_cover_handling :: proc(state: ^State, dt: Seconds) {
	if self.update_cover_timer > 0 {
		self.update_cover_timer -= dt

		if self.update_cover_timer <= 0 {
			_player_ui_update_cover(state)
		}
	}

	if cover, ok := self.loading_cover.?; ok {
		if !cover.loading {
			_player_ui_set_cover(state, cover)
			self.loading_cover = nil
		}
	}
}

player_ui_draw :: proc(state: ^State, ctx: ^ui.Context) {
	if !screen_is_visible(state, .Player) do return

	player := &state.player
	song, has_song := player_cur_or_last_song(player)

	box := ctx.box
	box.x += screen_x_offset(state, .Player)
	ui.begin_box(ctx, box, PLAYER_PADDING)

	offset: Vec2

	// Draw current song cover.
	{
		rect := cover_rect(.Huge, rect_pos(ctx.box))

		// TODO: would be cool to allow double-click on the cover and open it
		// in an external image viewer.

		// TODO: i should keep N next covers in an array and scroll through
		// them when the current song changes to get a smoother animation when
		// switching songs very fast. Currently if you switch a song too fast
		// the animation immidietely "snaps" if it is not finished yet.
		dir: i32
		easing := ease.Ease.Cubic_In_Out
		switch player.switch_direction {
		case .From_None:
			easing = .Cubic_Out
			dir = 1
		case .To_None:
			easing = .Cubic_In
			dir = 1
		case .Next:
			dir = 1
		case .Previous:
			dir = -1
		}

		progress := ui.tween_ease(&self.cover_tween, 1, easing)
		vw := f32(ui.state.view.width)
		if progress < 1 {
			r := rect
			r.x -= i32(vw * progress) * dir
			_player_ui_draw_cover(state, ctx, self.prev_cover, r)
		}

		{
			r := rect
			r.x += i32(vw * (1 - progress)) * dir
			_player_ui_draw_cover(state, ctx, self.cover, r)
		}

		offset.y += rect.height
	}

	// Draw song info.
	if has_song {
		offset.y += GAP * 3

		pos := rect_pos(ctx.box) + offset
		height := ctx.font_height * 2 + GAP

		pos.y += ctx.font_height
		pos.y += ICON_BUTTON_SIZE / 2 - height / 2
		ui.draw_text(ctx, song.title, pos, state.theme.black, bold = true)
		pos.y += ctx.font_height + GAP / 2

		artist := fmt.tprint(song.artist, '-', song.album)
		ui.draw_text(ctx, artist, pos, state.theme.gray)

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
		color := state.theme.black

		rect: Rect
		rect.y = ctx.box.y + offset.y
		rect.width = ICON_BUTTON_SIZE * 3
		rect.height = ICON_BUTTON_SIZE
		rect.x = ctx.box.x + ctx.box.width / 2 - rect.width / 2

		play_icon := icon_from_playstate(player.playstate)

		pos := rect_pos(rect)
		pos.x += btn(state, ctx, &self.button_prev, .Previous, pos, color)
		pos.x += btn(state, ctx, &self.button_play, play_icon, pos, color)
		pos.x += btn(state, ctx, &self.button_next, .Next, pos, color)

		offset.y += rect.height
	}
}

_player_ui_draw_cover :: proc(state: ^State, ctx: ^ui.Context, cover: Maybe(^Cover), rect: Rect) {
	if cover == nil do return

	drawn := cover_draw(ctx, cover, rect_pos(rect))
	if !drawn {
		// TODO: draw a proper placeholder.
		ui.draw_rect(ctx, rect, state.theme.gray)
	}

	ui.draw_box_bulgy(ctx, ui.pad(rect, -1), state.theme.black)
}

_player_ui_draw_slider :: proc(state: ^State, ctx: ^ui.Context) -> (height: i32) {
	player := &state.player

	elapsed_str := fmt.tprint(mpd.Seconds(player.elapsed))
	duration_str := fmt.tprint(mpd.Seconds(player.duration))

	rect := ctx.box.rect
	rect.y += height
	rect.height = ui.SLIDER_THICKNESS

	progress := player_progress(player)
	ui.slider_draw(ctx, &self.slider, progress, rect, state.theme.black, state.theme.gray)
	height += rect.height

	height += ctx.font_height * 2

	pos := rect_pos(ctx.box)
	pos.y += height
	ui.draw_text(ctx, elapsed_str, pos, state.theme.gray)
	pos.x += ctx.box.width
	ui.draw_text(ctx, duration_str, pos, state.theme.gray, align = .End)
	height += ctx.font_height

	return height
}

@(require_results)
player_ui_on_keyboard_key :: proc(state: ^State, ev: Key_Event) -> (propagate: bool) {
	if TEST_COVERS && ev.key == .Enter {
		new: int
		if ev.mods == {.Shift} {
			new = TEST_CUR_FILE - 1
			state.player.switch_direction = .Previous
		} else {
			new = TEST_CUR_FILE + 1
			state.player.switch_direction = .Next
		}
		if self.cover == nil {
			state.player.switch_direction = .From_None
		}

		TEST_CUR_FILE = ui.wrap(new, len(TEST_FILES))

		if new < 0 || len(TEST_FILES) <= new {
			_player_ui_set_cover(state, nil)
			state.player.switch_direction = .To_None
		} else {
			item := TEST_FILES[TEST_CUR_FILE]
			album := item[0]
			file := mpd.Song_File(item[1])
			_player_ui_request_cover(state, file, album, .Huge)
		}

		return false
	}

	return true
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
			_player_ui_set_cover(state, cover_ref(cover))
		} else {
			self.update_cover_timer = COVER_REQ_DELAY
		}
	} else {
		_player_ui_set_cover(state, nil)
	}
}

_player_ui_update_cover :: proc(state: ^State) {
	song, has_song := player_cur_song(&state.player)
	if has_song {
		_player_ui_request_cover(state, song.file, song.album, .Huge)
	} else {
		_player_ui_set_cover(state, nil)
	}
}

_player_ui_request_cover :: proc(
	state: ^State,
	file: mpd.Song_File,
	album: mpd.Album_Name,
	size: Cover_Size,
) {
	cover := cover_get_or_request(&state.player, file, album, .Huge)
	if cover.loading {
		// Do not set the new cover right away if it is loading. We'll wait
		// for the new cover to load and only then apply it.
		self.loading_cover = cover_ref(cover)
	} else {
		_player_ui_set_cover(state, cover_ref(cover))
	}
}

_player_ui_set_cover :: proc(state: ^State, cover: Maybe(^Cover)) {
	if prev, ok := self.prev_cover.?; ok {
		assert(prev.ref_count >= 2)
		cover_unref(prev)
	}
	self.prev_cover = self.cover
	self.cover = cover

	ui.tween_play(&self.cover_tween, 0, PLAYER_COVER_ANIM_DURATION)

	if PLAYER_ADAPT_THEME_TO_COVER {
		if cover, ok := cover.?; ok {
			set_background_from_cover(state, cover)
		} else {
			set_background(state, DEFAULT_BACKGROUND)
		}
	}
}

TEST_COVERS :: false
TEST_CUR_FILE: int = 0
TEST_FILES := [?][2]string {
	{`Telepathic Onset`, `Alec Normal/Telepathic Onset/001 One Floor Down.mp3`},
	{`Knives Out`, `Radiohead/Knives Out/001 Cuttooth.mp3`},
	{`Amnesiac`, `Radiohead/Amnesiac/009 Hunting Bears.mp3`},
	{`In Rainbows`, `Radiohead/In Rainbows/004 Weird Fishes ___ Arpeggi.mp3`},
	{
		`Her Revolution`,
		`Burial, Four Tet and Thom Yorke/Her Revolution ___ His Rope/001 Her Revolution.mp3`,
	},
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
