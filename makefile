SOURCES := $(shell find src/ -name '*.odin')

.PHONY: all

all: build build/mupwit
	@echo "DONE!"

build:
	mkdir -p build

build/mupwit: $(SOURCES)
	@echo "INFO: Compiling MUPWIT..."
	@odin build src -out:build/mupwit

clean:
	rm -r build

fmt:
	odin strip-semicolon src
