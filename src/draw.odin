package mupwit

import "lib:cairo"
import "lib:mpd"
import "lib:ui"

Seconds :: ui.Seconds
Rect :: ui.Rect
Vec2 :: ui.Vec2
Color :: ui.Color

rect_pos :: ui.rect_pos
rect_size :: ui.rect_size
rect_center :: ui.rect_center
within :: ui.within

Icon :: enum {
	Bar = 0,
	Play,
	Pause,
	Previous,
	Next,
	Small_Arrow_Right,
	Disk,
	Clear_Queue,
	Shuffle_Queue,
}

draw_icon :: proc(state: ^State, ctx: ^ui.Context, icon: Icon, pos: Vec2, color: Color) {
	ui.set_source_color(ctx, color)
	cairo.mask_surface(ctx, state.icons.sprites[icon], f64(pos.x), f64(pos.y))
}

draw_icon_button :: proc(
	state: ^State,
	ctx: ^ui.Context,
	button: ^ui.Button,
	icon: Icon,
	pos: Vec2,
	color: Color,
	size: i32 = ICON_BUTTON_SIZE,
) -> (
	advance: i32,
) {
	rect := Rect{pos.x, pos.y, size, size}
	ui.button_on_draw(button, rect)

	icon_pos := icon_center_inside(rect)
	if button.is_down do icon_pos.y += 1
	draw_icon(state, ctx, icon, icon_pos, color)

	return size
}

draw_action_button :: proc(
	state: ^State,
	ctx: ^ui.Context,
	button: ^ui.Button,
	icon: Icon,
	pos: Vec2,
) -> (
	advance: i32,
) {
	return draw_icon_button(state, ctx, button, icon, pos, state.theme.gray, TINY_BUTTON_SIZE)
}

icon_center_inside :: proc(inside: Rect) -> Vec2 {
	return rect_center(inside) - ICON_SIZE / 2
}

icon_from_playstate :: proc(playstate: mpd.Play_State) -> Icon {
	switch playstate {
	case .Stop:
		return .Play
	case .Pause:
		return .Play
	case .Play:
		return .Pause
	case:
		unreachable()
	}
}

scroll_draw :: proc(state: ^State, ctx: ^ui.Context, s: ^ui.Scroll, length: i32) {
	ui.scroll_draw(ctx, s, length, state.theme.light_gray, state.theme.gray)
}
