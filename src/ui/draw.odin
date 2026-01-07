package ui

import rl "vendor:raylib"

draw_normal_text :: proc(text: cstring, pos: rl.Vector2, color: rl.Color) {
	rl.DrawTextEx(assets.normal_font, text, pos, f32(assets.normal_font.baseSize), 0, color)
}
