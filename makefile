SOURCES := $(shell find src -name '*.odin')
LIB_SOURCES := $(shell find lib -name '*.odin')
PREBUILD_SOURCES := $(shell find prebuild -name '*.odin')
IMAGES := $(shell find assets/images -name '*.png')

FLAGS := \
	-error-pos-style:unix \
	-strict-style \
	-vet-tabs \
	-vet-unused \
	-vet-unused-variables \
	-vet-unused-imports \
	-vet-using-stmt \
	-terse-errors \
	-collection:lib=lib

ifdef DEBUG
BUILD_FLAGS := $(FLAGS) \
	-debug
else
BUILD_FLAGS := $(FLAGS) \
	-debug \
	-o:speed
endif

.PHONY: libs check

# Compile MUPWIT.
build/mupwit: $(SOURCES) $(LIB_SOURCES) assets/.generated
	@mkdir -p build
	@echo "INFO: Compiling..."
	@odin build src -out:build/mupwit $(BUILD_FLAGS)

# Prebuild assets.
assets/.generated: build/prebuild $(IMAGES)
	@echo "INFO: Running prebuild script..."
	@./build/prebuild
	@touch assets/.generated

build/prebuild: $(PREBUILD_SOURCES)
	@mkdir -p build
	@echo "INFO: Compiling prebuild script..."
	@odin build prebuild -out:build/prebuild $(FLAGS)


# Compile libraries.
libs:
	make -C./lib/my_window


# Miscellaneous.
check:
	@odin check src $(FLAGS)

fmt:
	@odinfmt src/ -w > /dev/null
	@odinfmt prebuild/ -w > /dev/null
	@odinfmt lib/ui/ -w > /dev/null
	@odinfmt lib/my_window/ -w > /dev/null
