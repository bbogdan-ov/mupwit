#ifndef CURRENTLY_PLAYING_H
#define CURRENTLY_PLAYING_H

#include "./draw.h"
#include "../context.h"
#include "./button.h"

#define CUR_PLAY_PADDING_Y 8
#define CUR_PLAY_HEIGHT (ICON_BUTTON_SIZE + CUR_PLAY_PADDING_Y*2)

void currently_playing_draw(Context ctx);

#endif
