package mupwit

import "lib:cairo"
import "lib:ui"

// ------------------------------
// UI.
// ------------------------------

// Base gap or padding between UI elements.
GAP :: 8

FONT_SIZE :: 16

ICON_BUTTON_SIZE :: 32

SONG_COVER_SIZE :: 32
SONG_HEIGHT :: SONG_COVER_SIZE + GAP * 2
// Whether to load covers for song items.
SONG_LOAD_COVER :: true

WINDOW_WIDTH :: 360
WINDOW_HEIGHT :: SONG_HEIGHT * 10 + GAP * 2

PLAYER_PADDING :: GAP * 5
// Delay between update of the current song (e.g. after you press "next") and
// requesting its cover.
PLAYER_COVER_UPDATE_DELAY :: Seconds(0.1)
// Cover transition duration.
PLAYER_COVER_ANIM_DURATION :: Seconds(0.5)

STATUS_HEIGHT :: ICON_BUTTON_SIZE + GAP * 2
STATUS_REVEAL_ANIM_DURATION :: Seconds(0.3)
QUEUE_STATUS_HEIGHT :: FONT_SIZE + GAP

SCREEN_ANIM_DURATION :: Seconds(0.3)
THEME_ANIM_DURATION :: PLAYER_COVER_ANIM_DURATION

ALBUM_GRID_COLUMS :: 2
ALBUM_COVER_SIZE :: WINDOW_WIDTH / ALBUM_GRID_COLUMS - GAP * 2 - GAP * (ALBUM_GRID_COLUMS - 1)
ALBUM_WIDTH :: ALBUM_COVER_SIZE + GAP * 2
ALBUM_HEIGHT :: ALBUM_WIDTH + FONT_SIZE
ALBUM_COVER_ANIM_DURATION :: Seconds(0.25)

COVER_SCALE_FILTER :: cairo.filter_t.GOOD
COVER_SIZE_HUGE :: WINDOW_WIDTH - PLAYER_PADDING * 2
COVER_SIZE_MEDIUM :: ALBUM_COVER_SIZE
COVER_SIZE_SMALL :: SONG_COVER_SIZE

// ------------------------------
// Colors.
// ------------------------------

BOBO_WHITE :: ui.Color{0xee, 0xee, 0xee, 0xff}
BOBO_BLACK :: ui.Color{0x11, 0x11, 0x11, 0xff}
RED :: ui.Color{0xff, 0x00, 0x00, 0xff}

DEFAULT_BACKGROUND :: BOBO_WHITE
