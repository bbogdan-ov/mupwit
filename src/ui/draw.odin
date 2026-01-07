package ui

import rl "vendor:raylib"

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

draw_text :: proc(text: cstring, pos: rl.Vector2, color := BLACK, scale: i32 = 1) -> (size: f32) {
	size = f32(assets.normal_font.baseSize * scale)
	rl.DrawTextEx(assets.normal_font, text, pos, size, 0, color)
	return
}
draw_italic_text :: proc(
	text: cstring,
	pos: rl.Vector2,
	color := BLACK,
	scale: i32 = 1,
) -> (
	size: f32,
) {
	size = f32(assets.italic_font.baseSize * scale)
	rl.DrawTextEx(assets.italic_font, text, pos, size, 0, color)
	return
}

draw_anim_texture :: proc(
	texture: rl.Texture,
	pos: rl.Vector2,
	frame: [2]i32,
	frames: [2]i32,
	tint := rl.WHITE,
) {
	frame_width := f32(texture.width / frames.x)
	frame_height := f32(texture.height / frames.y)
	source := rl.Rectangle {
		f32(frame.x) * frame_width,
		f32(frame.y) * frame_height,
		frame_width,
		frame_height,
	}
	dest := rl.Rectangle{pos.x, pos.y, frame_width, frame_height}

	rl.DrawTexturePro(texture, source, dest, {}, 0, tint)
}

draw_box :: proc(box: Box, rect: rl.Rectangle, color := BLACK) {
	FRAME_WIDTH :: 18
	FRAME_HEIGHT :: 18

	npatch := rl.NPatchInfo {
		source = {FRAME_WIDTH * f32(box), 0, FRAME_WIDTH, FRAME_HEIGHT},
		left   = 6,
		top    = 6,
		right  = 6,
		bottom = 6,
		layout = .NINE_PATCH,
	}
	rl.DrawTextureNPatch(assets.boxes, npatch, rect, {}, 0, color)
}

draw_icon :: proc(icon: Icon, pos: rl.Vector2, color := BLACK) {
	FRAME_WIDTH :: 16
	FRAME_HEIGHT :: 16

	source := rl.Rectangle{FRAME_WIDTH * f32(icon), 0, FRAME_WIDTH, FRAME_HEIGHT}
	dest := rl.Rectangle{pos.x, pos.y, FRAME_WIDTH, FRAME_HEIGHT}
	rl.DrawTexturePro(assets.icons, source, dest, {}, 0, color)
}
