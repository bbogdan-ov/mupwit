SOURCES       := $(shell find src/       -type f -name '*.odin')
BUILD_SOURCES := $(shell find build_src/ -type f -name '*.odin')
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

all: build build/rlgl.a build/assets/assets.odin build/mupwit
	@echo "DONE!"

build:
	mkdir -p build

build/mupwit: $(SOURCES) build/assets/assets.odin
	@echo "INFO: Compiling MUPWIT..."
	@odin build src -out:build/mupwit -debug $(FLAGS)

build/assets/assets.odin: build/decode_assets $(ASSETS)
	@echo "INFO: Decoding assets..."
	@mkdir -p build/assets/fonts
	@mkdir -p build/assets/images
	@./build/decode_assets

build/decode_assets: $(BUILD_SOURCES)
	@echo "INFO: Compiling assets decoder..."
	@odin build build_src/ -out:build/decode_assets -debug $(FLAGS)

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
