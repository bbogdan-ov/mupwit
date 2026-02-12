SOURCES       := $(shell find src/       -type f -iname '*.odin')
BUILD_SOURCES := $(shell find build_src/ -type f -iname '*.odin')
LIB_SOURCES   := $(shell find lib/       -type f -iname '*.odin')
ASSETS        := $(shell find assets/    -type f)

FLAGS := \
	-terse-errors \
	-error-pos-style:unix \
	-strict-style \
	-vet-tabs \
	-vet-unused \
	-vet-unused-variables \
	-vet-unused-imports \
	-vet-using-stmt

.PHONY: all

all: build build/mupwit
	@echo "DONE!"

build:
	mkdir -p build

build/mupwit: $(SOURCES) $(LIB_SOURCES) build/rlgl.a build/assets/assets.odin
	@echo "INFO: Compiling MUPWIT..."
	@odin build src -out:build/mupwit -debug $(FLAGS)

build/assets/assets.odin: build/build $(ASSETS)
	@echo "INFO: Running build script..."
	@mkdir -p build/assets/fonts
	@mkdir -p build/assets/images
	@./build/build

build/build: $(BUILD_SOURCES)
	@echo "INFO: Compiling build script..."
	@odin build build_src/ -out:build/build -debug $(FLAGS)

build/rlgl.a: lib/rlgl.h
	@echo "INFO: Compiling rlgl object file..."
	@gcc \
		-DRLGL_IMPLEMENTATION \
		-DGRAPHICS_API_OPENGL_33 \
		-lm -c -x c -o build/rlgl.a lib/rlgl.h

clean:
	rm -r build

check:
	@odin check src $(FLAGS)
