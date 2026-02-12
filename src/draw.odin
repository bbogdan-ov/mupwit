package mupwit

import "../lib/ui"
import "../lib/ui/rlgl"

Box :: enum byte {
	Normal = 0,
	Rounded,
	Thick,
	Filled_Rounded,
	Filled_Normal,
}

Icon :: enum byte {
	Progress_Thumb = 0,
	Play,
	Pause,
	Previous,
	Next,
	Small_Arrow_Right,
	Disk,
}

draw_box :: proc(box: Box, rect: ui.Rect, color := BLACK) {
	FRAME_WIDTH :: 18
	FRAME_HEIGHT :: 18
	// Padding - width and height of each segment in the 9-slice texture
	P :: 6

	source := ui.Rect{FRAME_WIDTH * f32(box), 0, FRAME_WIDTH, FRAME_HEIGHT}
	sx := source.x
	sy := source.y
	sw := source.width
	sh := source.height

	rx := rect.x - P / 2
	ry := rect.y - P / 2
	rw := rect.width + P
	rh := rect.height + P

	rlgl.SetTexture(assets.boxes.id)
	rlgl.Begin(rlgl.QUADS)

	// Top left corner
	ui.draw_texture_impl(assets.boxes, {sx, sy, P, P}, {rx, ry, P, P}, tint = color)

	// Top edge
	ui.draw_texture_impl(
		assets.boxes,
		{sx + P, sy, sw - P * 2, P},
		{rx + P, ry, rw - P * 2, P},
		tint = color,
	)

	// Top right corner
	ui.draw_texture_impl(
		assets.boxes,
		{sx + sw - P, sy, P, P},
		{rx + rw - P, ry, P, P},
		tint = color,
	)

	// Right edge
	ui.draw_texture_impl(
		assets.boxes,
		{sx + sw - P, sy + P, P, sh - P * 2},
		{rx + rw - P, ry + P, P, rh - P * 2},
		tint = color,
	)

	// Bottom right corner
	ui.draw_texture_impl(
		assets.boxes,
		{sx + sw - P, sy + sh - P, P, P},
		{rx + rw - P, ry + rh - P, P, P},
		tint = color,
	)

	// Bottom edge
	ui.draw_texture_impl(
		assets.boxes,
		{sx + P, sy + sh - P, sw - P * 2, P},
		{rx + P, ry + rh - P, rw - P * 2, P},
		tint = color,
	)

	// Bottom left corner
	ui.draw_texture_impl(
		assets.boxes,
		{sx, sy + sh - P, P, P},
		{rx, ry + rh - P, P, P},
		tint = color,
	)

	// Left edge
	ui.draw_texture_impl(
		assets.boxes,
		{sx, sy + P, P, sh - P * 2},
		{rx, ry + P, P, rh - P * 2},
		tint = color,
	)

	// Middle
	if box == .Filled_Rounded || box == .Filled_Normal {
		ui.draw_texture_impl(
			assets.boxes,
			{sx + P, sy + P, sw - P * 2, sh - P * 2},
			{rx + P, ry + P, rw - P * 2, rh - P * 2},
			tint = color,
		)
	}

	rlgl.End()
}

ICON_SIZE :: 16

draw_icon :: proc(icon: Icon, pos: ui.Point, color := BLACK) {
	source := ui.Rect{ICON_SIZE * f32(icon), 0, ICON_SIZE, ICON_SIZE}
	dest := ui.Rect{pos.x, pos.y, ICON_SIZE, ICON_SIZE}
	ui.draw_texture_ex(assets.icons, source, dest, color)
}

draw_normal_text :: #force_inline proc(
	text: string,
	pos: ui.Point,
	color := BLACK,
	scale: f32 = 1,
) -> (
	advance: ui.Point,
) {
	return ui.draw_text(assets.normal_font, text, pos, color, scale)
}
