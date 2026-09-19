package ui

Slider :: struct {
	rect:        Rect,
	progress:    f32,
	is_hovering: bool,
}

slider_update :: proc(s: ^Slider) -> (changed: bool) {
	id := Element_ID(s)
	is_dragging := state.dragging == id

	s.is_hovering = is_hovering(s.rect)

	if s.is_hovering || is_dragging {
		set_cursor(.Pointer)
	}

	switch {
	case is_dragging:
		px := f32(state.pointer.x - s.rect.x)
		s.progress = px / f32(s.rect.width)
		s.progress = clamp(s.progress, 0, 1)

		changed = is_mouse_released(.Left)

	case s.is_hovering && is_mouse_pressed(.Left) && state.dragging == nil:
		start_dragging(id)
	}

	return changed
}

slider_draw :: proc(
	ctx: ^Context,
	s: ^Slider,
	progress: f32,
	rect: Rect,
	color: Color,
	thumb := true,
) {
	rect := rect
	rect.height = SLIDER_THICKNESS

	s.rect = rect
	s.rect.height = SLIDER_CLICK_THICKNESS
	s.rect.y += (rect.height - s.rect.height) / 2

	is_dragging := state.dragging == Element_ID(s)
	if !is_dragging {
		s.progress = progress
	}

	draw_box(ctx, rect, color)
	bar := pad(rect, {0, 1})
	bar.width = i32(f32(bar.width) * s.progress)
	draw_rect(ctx, bar, color)

	if thumb {
		rect: Rect
		rect.width = SLIDER_THICKNESS
		rect.height = SLIDER_CLICK_THICKNESS + 2
		rect.x = bar.x + bar.width - rect.width / 2
		rect.y = bar.y + bar.height / 2 - rect.height / 2
		draw_box(ctx, rect, color, true)
	}
}
