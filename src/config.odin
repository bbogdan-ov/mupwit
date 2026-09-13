package mupwit

import "lib:ui"

// ------------------------------
// Values.
// ------------------------------

GAP :: 8 // Base gap or padding between UI elements.

SONG_COVER_SIZE :: 32
SONG_HEIGHT :: SONG_COVER_SIZE + GAP * 2

WINDOW_WIDTH :: 360
WINDOW_HEIGHT :: SONG_HEIGHT * 10 + GAP * 2

// ------------------------------
// Colors.
// ------------------------------

WHITE :: ui.Color{0xee, 0xee, 0xee, 0xff}
LIGHT_GRAY :: ui.Color{0x11, 0x11, 0x11, 40}
GRAY :: ui.Color{0x11, 0x11, 0x11, 160}
BLACK :: ui.Color{0x11, 0x11, 0x11, 0xff}
RED :: ui.Color{0xff, 0x00, 0x00, 0xff}
