package mupwit

import "lib:cairo"
import "lib:ui"

// ------------------------------
// UI.
// ------------------------------

// Base gap or padding between UI elements.
GAP :: 8

FONT_SIZE :: 16

ICON_SIZE :: 16
ICON_BUTTON_SIZE :: 32
TINY_BUTTON_SIZE :: ICON_SIZE

SONG_COVER_SIZE :: 32
SONG_HEIGHT :: SONG_COVER_SIZE + GAP * 2
// Whether to load covers for song items.
SONG_LOAD_COVER :: true

WINDOW_WIDTH :: 360
WINDOW_HEIGHT :: SONG_HEIGHT * 10 + GAP * 2

PLAYER_PADDING :: GAP * 5
// Cover transition duration.
PLAYER_COVER_ANIM_DURATION :: Seconds(0.5)
PLAYER_ADAPT_THEME_TO_COVER :: true

STATUS_REVEAL_ANIM_DURATION :: Seconds(0.3)
STATUS_HEIGHT :: ICON_BUTTON_SIZE + GAP * 2
QUEUE_STATUS_HEIGHT :: FONT_SIZE + GAP
STATUS_MAX_HEIGHT :: STATUS_HEIGHT + QUEUE_STATUS_HEIGHT

SCREEN_ANIM_DURATION :: Seconds(0.3)
THEME_ANIM_DURATION :: PLAYER_COVER_ANIM_DURATION

ALBUM_GRID_COLUMS :: 2
ALBUM_COVER_SIZE :: WINDOW_WIDTH / ALBUM_GRID_COLUMS - GAP * 2 - GAP * (ALBUM_GRID_COLUMS - 1)
ALBUM_WIDTH :: ALBUM_COVER_SIZE + GAP * 2
ALBUM_HEIGHT :: ALBUM_WIDTH + FONT_SIZE

COMMAND_ANIM_DURATION :: Seconds(0.2)

COVER_REQ_DELAY :: Seconds(0.15)
COVER_ALPHA_ANIM_DURATION :: Seconds(0.1)
COVER_SCALE_FILTER :: cairo.filter_t.GOOD
COVER_SIZE_HUGE :: WINDOW_WIDTH - PLAYER_PADDING * 2
COVER_SIZE_MEDIUM :: ALBUM_COVER_SIZE
COVER_SIZE_SMALL :: SONG_COVER_SIZE

UNKNOWN :: "<unknown>"

// ------------------------------
// Misc.
// ------------------------------

// Time untill it is allowed to save an another queue state into the history.
// It helps to save the current state of the queue in the history only once if
// queue changes are frequent, for example when you do `mpc clear; mpc load
// playlist; mpc shuffle` it changes the queue 3 times and the state of the
// queue will be saved 3 times which is not what i want.
PLAYER_QUEUE_HISTORY_DEBOUNCE :: Seconds(0.2)

HISTORY_LIMIT :: 64

// ------------------------------
// Colors.
// ------------------------------

WHITE :: ui.Color{0xee, 0xee, 0xee, 0xff}
BLACK :: ui.Color{0x11, 0x11, 0x11, 0xff}
RED :: ui.Color{0xff, 0x00, 0x00, 0xff}

DEFAULT_BACKGROUND :: WHITE
