#ifndef BUTTON_H
#define BUTTON_H

#include "./draw.h"
#include "../state.h"

#define ICON_BUTTON_SIZE 32

bool draw_icon_button(State *state, Icon icon, Vec pos);

#endif
