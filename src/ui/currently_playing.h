#ifndef CURRENTLY_PLAYING_H
#define CURRENTLY_PLAYING_H

#include "./draw.h"
#include "./button.h"
#include "../client.h"
#include "../state.h"

#define CUR_PLAY_PADDING_Y 8
#define CUR_PLAY_HEIGHT (ICON_BUTTON_SIZE + CUR_PLAY_PADDING_Y*2)

void currently_playing_draw(Client *client, State *state);

#endif
