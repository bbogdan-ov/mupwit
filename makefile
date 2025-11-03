FLAGS := -Wall -Wextra -std=c99 -pedantic
LIBS := -lraylib -lmpdclient -lm -lGL

SOURCES := $(shell find src/ -name '*.c')
INCLUDES := $(shell find src/ -name '*.h')
ASSETS := $(shell find assets/ -name '*.ttf' -or -name '*.png')

ifdef DEBUG
CFLAGS := $(CFLAGS) -DDEBUG
endif

ifdef RELEASE
CFLAGS := $(CFLAGS) -O3 -DRELEASE
endif

.PHONY: all

all: build build/mupwit
	@echo "DONE!"

build:
	mkdir -p build

# Build!!!
build/mupwit: $(SOURCES) $(INCLUDES) build/assets.h build/assets.o
	@echo "Compiling MUPWIT..."
	@gcc $(CFLAGS) $(FLAGS) $(LIBS) \
		$(SOURCES) build/assets.o -o build/mupwit

# Compile 'assets.h' down to an object file so we don't compile it every time we
# change source files of the projects
build/assets.o: build/assets.c build/assets.h
	@echo "Precompiling assets object file..."
	@gcc $(FLAGS) -c -x c -O3 \
		build/assets.c -o build/assets.o

# Generate 'assets'.h
build/assets.h: build/gen_assets $(ASSETS)
	@echo "Generating assets..."
	@build/gen_assets

# Compile 'gen_assets'
build/gen_assets: build_src/gen_assets.c
	@echo "Compiling 'gen_assets.c'..."
	@gcc $(FLAGS) -lraylib -lm \
		build_src/gen_assets.c -o build/gen_assets

clean:
	rm -r build
