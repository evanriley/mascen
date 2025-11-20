PREFIX ?= /usr/local
BINDIR ?= $(PREFIX)/bin
ZIG ?= zig
ZIG_FLAGS ?= -Doptimize=ReleaseSafe

OUT = zig-out/bin/mascen

.PHONY: all build install uninstall clean

all: build

# 'build' is PHONY to ensure we always let Zig handle incremental compilation checks
build:
	$(ZIG) build $(ZIG_FLAGS)

# 'install' depends on the artifact file, NOT the 'build' target.
# This allows 'sudo make install' to succeed without needing 'zig' in root's PATH,
# provided the user has already run 'make' to build the artifact.
install: $(OUT)
	install -Dm755 $(OUT) $(DESTDIR)$(BINDIR)/mascen

# If the artifact does not exist, we must try to build it.
$(OUT):
	$(ZIG) build $(ZIG_FLAGS)

uninstall:
	rm -f $(DESTDIR)$(BINDIR)/mascen

clean:
	rm -rf zig-out zig-cache
