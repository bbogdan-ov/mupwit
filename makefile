SRC_DIR := ./src
BUILD_SRC_DIR := ./build_src
BUILD_DIR := ./build

FLAGS := -Wall -Wextra -std=c99 -pedantic
LIBS := -lraylib -lmpdclient -lm

SOURCES := $(shell find $(SRC_DIR) -name '*.c')
INCLUDES := $(shell find $(SRC_DIR) -name '*.h')
ASSETS := $(shell find assets/ -name '*.ttf' -or -name '*.png')

ifdef DEBUG
CFLAGS := $(CFLAGS) -DDEBUG
endif

ifdef RELEASE
CFLAGS := $(CFLAGS) -O3 -DRELEASE
endif

# Build!!!
$(BUILD_DIR)/mupwit: $(SOURCES) $(INCLUDES) $(BUILD_DIR)/assets.h $(BUILD_DIR)/assets.o
	gcc $(CFLAGS) $(FLAGS) $(LIBS) \
		$(SOURCES) $(BUILD_DIR)/assets.o -o $(BUILD_DIR)/mupwit

# Compile 'assets.h' down to an object file so we don't compile it every time we
# change source files of the projects
$(BUILD_DIR)/assets.o: $(BUILD_DIR)/assets.h
	gcc $(FLAGS) -DASSETS_IMPLEMENTATION -c -x c -O3 \
		$(BUILD_DIR)/assets.h -o $(BUILD_DIR)/assets.o

# Generate 'assets'.h
$(BUILD_DIR)/assets.h: $(BUILD_DIR)/gen_assets $(ASSETS)
	$(BUILD_DIR)/gen_assets

# Compile 'gen_assets'
$(BUILD_DIR)/gen_assets: $(BUILD_SRC_DIR)/gen_assets.c | $(BUILD_DIR)
	gcc $(FLAGS) -lraylib -lm \
		$(BUILD_SRC_DIR)/gen_assets.c -o $(BUILD_DIR)/gen_assets

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

clean:
	rm -r build
