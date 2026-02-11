package mupwit

import "ui"

queue_page_draw :: proc(queue: Queue) {
	GAP :: 10

	pos := ui.Point{10, 10}

	for song in queue.songs {
		if title, ok := song.title.?; ok {
			pos.y += ui.draw_text(title, pos) + GAP
		} else {
			pos.y += ui.draw_text("<no title>", pos) + GAP
		}
	}
}
