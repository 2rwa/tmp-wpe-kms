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
	@set -eu; python3 -m http.server 8766 --directory docs >/tmp/wpe-kms-server.log 2>&1 & server=$!; trap 'kill $server 2>/dev/null || true' EXIT; sleep 2; WPE_PLATFORM=headless timeout 75s ./$(BIN) --test http://127.0.0.1:8766/
clean:
	rm -rf dist
