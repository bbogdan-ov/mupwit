package mupwit

// ------------------------------
// MUPWIT configuration goes here!
//
// There is no some sort of a "runtime config file", you have to edit this file
// and recompile the app.
//
// Also see `./lib/ui/config.odin` for more advanced configuration.
// ------------------------------

import "../lib/ui"

// --------------------
// Window
// --------------------

WINDOW_TITLE :: "MUPWIT"
WINDOW_WIDTH :: 360
WINDOW_HEIGHT :: 440

// --------------------
// Layout
// --------------------

GAP :: 8 // Base gap

QUEUE_SONG_COVER_SIZE :: 32

// --------------------
// Colors
// --------------------

WHITE :: ui.Color{0xdd, 0xdd, 0xdd, 0xff}
BLACK :: ui.Color{0x11, 0x11, 0x11, 0xff}
GRAY :: ui.Color{BLACK.r, BLACK.g, BLACK.b, 140}
LIGHTGRAY :: ui.Color{BLACK.r, BLACK.g, BLACK.b, 60}

BACKGROUND :: WHITE

// --------------------
// Strings
// --------------------

UNKNOWN :: "<unknown>"
