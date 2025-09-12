SRC_DIR := ./src
BUILD_SRC_DIR := ./build_src
BUILD_DIR := ./build

FLAGS := -Wall -Wextra -std=c99 -pedantic
LIBS := -lraylib -lmpdclient -lm

SOURCES := $(shell find $(SRC_DIR) -name '*.c')
INCLUDES := $(shell find $(SRC_DIR) -name '*.h')
FONTS := $(shell find assets/fonts/ -name '*.ttf')

$(BUILD_DIR)/mupwit: $(SOURCES) $(INCLUDES) $(BUILD_DIR)/fonts.c
	gcc $(FLAGS) $(LIBS) -O3 \
		$(SOURCES) -o ./$(BUILD_DIR)/mupwit

$(BUILD_DIR)/fonts.c: $(BUILD_SRC_DIR)/ttf2c.c $(FONTS) | $(BUILD_DIR)
	gcc $(FLAGS) -lm \
		$(BUILD_SRC_DIR)/ttf2c.c -o ./$(BUILD_DIR)/ttf2c
	$(BUILD_DIR)/ttf2c

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)
