package ui

@(require_results)
rect_contains_point :: #force_inline proc "contextless" (rect: Rect, point: Point) -> bool {
	return(
		point.x >= rect.x &&
		point.y >= rect.y &&
		point.x < rect.x + rect.width &&
		point.y < rect.y + rect.height \
	)
}

@(require_results)
rect_shrink :: #force_inline proc "contextless" (
	rect: Rect,
	horizontal: f32,
	vertical: f32,
) -> Rect {
	rect := rect
	rect.x += horizontal
	rect.y += vertical
	rect.width -= horizontal * 2
	rect.height -= vertical * 2
	return rect
}
