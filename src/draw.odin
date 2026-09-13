package mupwit

import "lib:cairo"
import "lib:ui"

Seconds :: ui.Seconds
Vec2 :: ui.Vec2
Color :: ui.Color

rect_pos :: ui.rect_pos
rect_size :: ui.rect_size
rect_center :: ui.rect_center
rect_expand :: ui.rect_expand

ICON_SIZE :: 16

Icon :: enum {
	Bar = 0,
	Play,
	Pause,
	Previous,
	Next,
	Small_Arrow_Right,
	Disk,
}

draw_icon :: proc(ctx: ^ui.Context, icon: Icon, pos: Vec2, color: Color) {
	ui.set_source_color(ctx, color)
	cairo.mask_surface(ctx, state.icons.sprites[icon], f64(pos.x), f64(pos.y))
}
