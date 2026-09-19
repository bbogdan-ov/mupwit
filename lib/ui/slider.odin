package ui

Slider :: struct {
	rect:        Rect,
	progress:    f32,
	is_hovering: bool,
	is_dragging: bool,
}

slider_update :: proc(s: ^Slider) -> (changed: bool) {
	id := Element_ID(s)

	s.is_dragging = state.dragging == id
	s.is_hovering = is_hovering(s.rect)

	if s.is_hovering || s.is_dragging {
		set_cursor(.Pointer)
	}

	switch {
	case s.is_dragging:
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
	color, track_color: Color,
	thumb := true,
) {
	rect := rect
	rect.height = SLIDER_THICKNESS

	s.rect = rect
	s.rect.height = SLIDER_CLICK_THICKNESS
	s.rect.y += (rect.height - s.rect.height) / 2

	if !s.is_dragging {
		s.progress = progress
	}

	// Draw track.
	draw_rect(ctx, pad(rect, {0, 1}), track_color)

	// Draw progress bar.
	bar := rect
	bar.width = i32(f32(bar.width) * s.progress)
	draw_box(ctx, bar, color, filled = true)

	if thumb {
		rect: Rect
		rect.width = SLIDER_THICKNESS
		rect.height = SLIDER_CLICK_THICKNESS + 2
		rect.x = bar.x + bar.width - rect.width / 2
		rect.y = bar.y + bar.height / 2 - rect.height / 2
		draw_box(ctx, rect, color, true)
	}
}

slider_is_dragging :: proc(s: ^Slider) -> bool {
	return state.dragging == Element_ID(s)
}
