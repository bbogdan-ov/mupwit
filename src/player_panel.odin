package mupwit

import "core:log"

import "../lib/ui"

PLAYER_PANEL_HEIGHT :: ICON_BUTTON_SIZE + GAP * 2

player_panel_draw :: proc() {
	container := ui.Rect {
		0,
		ui.window.height - PLAYER_PANEL_HEIGHT,
		ui.window.width,
		PLAYER_PANEL_HEIGHT,
	}

	// Draw panel background and border
	{
		ui.draw_rect(container, BACKGROUND)
		border := container
		border.height = 1
		ui.draw_rect(border, BLACK)
	}

	pressed := draw_icon_button(.Play, {GAP, container.y + GAP})
	if pressed do log.info("hey")
}
