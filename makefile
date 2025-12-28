SOURCES := $(shell find src/ -name '*.odin')

FLAGS := \
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

build/mupwit: $(SOURCES)
	@echo "INFO: Compiling MUPWIT..."
	@odin build src -out:build/mupwit -debug $(FLAGS)

clean:
	rm -r build

check:
	@odin check src $(FLAGS)
