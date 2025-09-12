FLAGS := -Wall -Wextra -std=c99 -pedantic

LIBS := -lraylib -lmpdclient -lm

INCLUDES := src/main.c src/draw.c src/client.c src/player.c src/state.c \
			src/tabs/player_tab.c

mupwit: $(INCLUDES)
	gcc $(FLAGS) $(LIBS) \
		-o mupwit \
		$(INCLUDES)
