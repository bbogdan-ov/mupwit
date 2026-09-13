package mupwit

import "core:math/ease"
// ------------------------------
// Values.
// ------------------------------

GAP :: 8 // Base gap or padding between UI elements.

SCROLL_WHEEL_MULPLIER :: 6
SCROLL_TOUCH_MULPLIER :: 4
SCROLL_ANIM_DURATION :: Seconds(0.2)
SCROLL_ANIM_EASE :: ease.sine_out
SCROLL_VELOCITY_DRAG :: 10
SCROLL_THUMB_THICKNESS :: 2

SONG_COVER_SIZE :: 32
SONG_HEIGHT :: SONG_COVER_SIZE + GAP * 2

WINDOW_WIDTH :: 360
WINDOW_HEIGHT :: SONG_HEIGHT * 10 + GAP * 2

// ------------------------------
// Colors.
// ------------------------------

WHITE :: Color{0xee, 0xee, 0xee, 0xff}
LIGHT_GRAY :: Color{0x11, 0x11, 0x11, 40}
GRAY :: Color{0x11, 0x11, 0x11, 160}
BLACK :: Color{0x11, 0x11, 0x11, 0xff}
RED :: Color{0xff, 0x00, 0x00, 0xff}
