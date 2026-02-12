package ui

rect_contains_point :: proc(rect: Rect, point: Point) -> bool {
	return(
		point.x >= rect.x &&
		point.y >= rect.y &&
		point.x < rect.x + rect.width &&
		point.y < rect.y + rect.height \
	)
}

rect_shrink :: proc(rect: Rect, horizontal: f32, vertical: f32) -> Rect {
	rect := rect
	rect.x += horizontal
	rect.y += vertical
	rect.width -= horizontal * 2
	rect.height -= vertical * 2
	return rect
}
