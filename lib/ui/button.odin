package ui

Button :: struct {
	rect:        Rect,
	is_hovering: bool,
	is_down:     bool,
}

button_update :: proc(b: ^Button) -> (clicked: bool) {
	was_down := b.is_down
	b.is_hovering = state.dragging == nil && overlap(state.pointer, b.rect)
	b.is_down = b.is_hovering && is_mouse_down(.Left)
	return was_down && is_mouse_released(.Left)
}

button_on_draw :: proc(b: ^Button, rect: Rect) {
	b.rect = rect
}
