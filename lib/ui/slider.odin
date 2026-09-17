package ui

Slider :: struct {
	rect:        Rect,
	progress:    f32,
	is_hovering: bool,
}

slider_update :: proc(s: ^Slider) -> (changed: bool) {
	id := Element_ID(s)
	is_dragging := state.dragging == id

	switch {
	case is_dragging && is_mouse_down(.Left):
		px := f32(state.pointer.x - s.rect.x)
		s.progress = px / f32(s.rect.width)
		s.progress = clamp(s.progress, 0, 1)

	case is_dragging:
		stop_dragging(id)
		changed = true

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

	click := rect
	click.height = SLIDER_CLICK_THICKNESS
	click.y += (rect.height - click.height) / 2

	s.rect = rect
	s.is_hovering = is_hovering(click)

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
