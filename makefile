SOURCES       := $(shell find src/       -type f -name '*.odin')
BUILD_SOURCES := $(shell find build_src/ -type f -name '*.odin')
ASSETS        := $(shell find assets/    -type f)

FLAGS := \
	-error-pos-style:unix \
	-strict-style \
	-vet-tabs \
	-vet-unused \
	-vet-unused-variables \
	-vet-unused-imports \
	-vet-using-stmt

.PHONY: all

all: build build/assets/assets.odin build/mupwit
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
	@odin build build_src/ -out:build/decode_assets $(FLAGS)

clean:
	rm -r build

check:
	@odin check src $(FLAGS) -terse-errors
