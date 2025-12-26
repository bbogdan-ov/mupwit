SOURCES := $(shell find src/ -name '*.odin')

.PHONY: all

all: build build/mupwit
	@echo "DONE!"

build:
	mkdir -p build

build/mupwit: $(SOURCES)
	@echo "INFO: Compiling MUPWIT..."
	@odin build src -out:build/mupwit -debug \
		-error-pos-style:unix \
		-strict-style \
		-vet-tabs \
		-vet-unused \
		-vet-unused-variables \
		-vet-unused-imports \
		-vet-using-stmt

clean:
	rm -r build

fmt:
	odin strip-semicolon src
