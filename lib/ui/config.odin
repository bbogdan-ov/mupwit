package ui

import "core:math/ease"

SCROLL_WHEEL_MULPLIER :: 6
SCROLL_TOUCH_MULPLIER :: 4
SCROLL_ANIM_DURATION :: Seconds(0.2)
SCROLL_ANIM_EASE :: ease.sine_out
SCROLL_VELOCITY_DRAG :: 16
SCROLL_THUMB_THICKNESS :: 2

SLIDER_THICKNESS :: 4
SLIDER_CLICK_THICKNESS :: 12

// Threshold from top or bottom that should be hovered by a reodering item to
// start scrolling.
ITEM_REORDER_SCROLLOFF :: 32
ITEM_REORDER_SCROLL_MUL :: 0.25

// Time between mouse clicks to count it as a double-click.
DOUBLE_CLICK_DURATION :: Seconds(0.3)
