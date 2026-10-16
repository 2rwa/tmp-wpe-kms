CC ?= cc
CFLAGS ?= -O2 -g
PKGS = wpe-webkit-2.0 wpe-platform-2.0
BIN = dist/wpe-kms-launcher
.PHONY: all check clean
all: $(BIN)
$(BIN): src/main.c
	mkdir -p dist
	$(CC) -std=c11 -Wall -Wextra -Werror $(CFLAGS) -o $@ $< $(shell pkg-config --cflags --libs $(PKGS))
check: $(BIN)
	pkg-config --exists wpe-platform-drm-2.0
	pkg-config --exists wpe-platform-headless-2.0
	WPE_PLATFORM=headless timeout 75s ./$(BIN) --test file://$(abspath docs/index.html)
clean:
	rm -rf dist
