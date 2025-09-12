SRC_DIR := ./src
BUILD_SRC_DIR := ./build_src
BUILD_DIR := ./build

FLAGS := -Wall -Wextra -std=c99 -pedantic
LIBS := -lraylib -lmpdclient -lm

SOURCES := $(shell find $(SRC_DIR) -name '*.c')
INCLUDES := $(shell find $(SRC_DIR) -name '*.h')
FONTS := $(shell find assets/fonts/ -name '*.ttf')

# Build!!!
$(BUILD_DIR)/mupwit: $(SOURCES) $(INCLUDES) $(BUILD_DIR)/fonts.h $(BUILD_DIR)/fonts.o
	gcc $(CFLAGS) $(FLAGS) $(LIBS) \
		$(SOURCES) $(BUILD_DIR)/fonts.o -o $(BUILD_DIR)/mupwit

# Compile fonts.h down to an object file so we don't compile it every time we
# change source files of the projects
$(BUILD_DIR)/fonts.o: $(BUILD_DIR)/fonts.h
	gcc $(FLAGS) -DFONTS_IMPLEMENTATION -c -x c -O3 \
		$(BUILD_DIR)/fonts.h -o $(BUILD_DIR)/fonts.o

# Generate fonts.h that contains rasterized fonts data
$(BUILD_DIR)/fonts.h: $(BUILD_SRC_DIR)/ttf2h.c $(FONTS) | $(BUILD_DIR)
	gcc $(FLAGS) -lm \
		$(BUILD_SRC_DIR)/ttf2h.c -o $(BUILD_DIR)/ttf2h
	$(BUILD_DIR)/ttf2h

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

clean:
	rm -r build
