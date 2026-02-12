package mupwit

import "ui"

queue_page_draw :: proc(queue: Queue) {
	GAP :: 10

	pos := ui.Point{10, 10}

	if len(queue.songs) == 0 {
		ui.draw_text("no songs", pos)
		return
	}

	for song in queue.songs {
		if i32(pos.y) > ui.window.height {
			break
		}

		if title, ok := song.title.?; ok {
			pos.y += ui.draw_text(title, pos) + GAP
		} else {
			pos.y += ui.draw_text("<no title>", pos) + GAP
		}
	}
}
