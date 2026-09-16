# Default target
help:
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  help       Show this help message"
	@echo "  build      Build the Debian package"
	@echo "  clean      Remove generated files"
	@echo "  check-gists  Report drift between this repo and the upstream gists"
	@echo "  print-version  Print the package version (used by CI to tag releases)"
	@echo "  pull-gists   Overwrite repo files FROM the gists (destructive)"

PACKAGE_NAME := brent-install
VERSION := 1.3.0
BUILD_DIR := $(PACKAGE_NAME)
DEB_FILE := $(PACKAGE_NAME)_$(VERSION).deb

all: build

# CI tags the release from this, so the Makefile is the one place a version
# is defined. Bump VERSION above when the package contents change.
print-version:
	@echo $(VERSION)

build: prepare
	dpkg-deb --build $(BUILD_DIR) $(DEB_FILE)

prepare:
	@echo "Creating directory structure..."
	rm -rf $(BUILD_DIR)
	mkdir -p $(BUILD_DIR)/DEBIAN
	mkdir -p $(BUILD_DIR)/usr/share/$(PACKAGE_NAME)/to_home_dir
	mkdir -p $(BUILD_DIR)/usr/share/$(PACKAGE_NAME)/scripts

	@echo "Copying control file and scripts..."
	# Stamp the version from VERSION above rather than copying control verbatim.
	# The two were maintained by hand and had already drifted: control said
	# 1.1.0 while the .deb filename came from VERSION, so the package metadata
	# and the artifact name could disagree silently.
	sed 's/^Version: .*/Version: $(VERSION)/' control > $(BUILD_DIR)/DEBIAN/control
	cp postinst $(BUILD_DIR)/DEBIAN/postinst
	chmod 755 $(BUILD_DIR)/DEBIAN/postinst

	@echo "Copying files and setup script..."
	-@cp -r to_home_dir/. $(BUILD_DIR)/usr/share/$(PACKAGE_NAME)/to_home_dir/ 2>/dev/null || true
	-@cp -r to_scripts/.  $(BUILD_DIR)/usr/share/$(PACKAGE_NAME)/scripts/ 2>/dev/null || true
	cp setup.sh $(BUILD_DIR)/usr/share/$(PACKAGE_NAME)/scripts/

clean:
	rm -rf $(BUILD_DIR)
	rm -f $(DEB_FILE)

# Files that were originally authored as gists. THIS REPO IS THE SOURCE OF
# TRUTH for them: it has review, history and the ability to roll back, and the
# gists have none of that. Several of these files have been edited here for
# months while the gists sat still, so the old blanket "download and overwrite"
# update target was a loaded gun — one `make update` silently reverted every
# in-repo commit touching them. It is now a drift *check*; pulling is explicit.
GIST_BASE := https://gist.githubusercontent.com/byates

GIST_FILES := \
	to_home_dir/.tmux.conf:d04215a3dc88cf47015fea28d419e64e/raw/.tmux.conf \
	to_home_dir/.vimrc:d04215a3dc88cf47015fea28d419e64e/raw/.vimrc \
	to_home_dir/.jby_bashrc.sh:d04215a3dc88cf47015fea28d419e64e/raw/jby_bashrc.sh \
	to_home_dir/.gitconfig.inc:dd4f8dc9069c15f7cb2179df4dca78bc/raw/.gitconfig.inc \
	to_home_dir/force-clean-repo.sh:d049f99a8e24cdcaf87752be414a18de/raw/force-clean-repo.sh \
	to_scripts/test-24-bit-color.sh:b6ded34f2c7436cac9898d92abb8a0d1/raw/test-24-bit-color.sh \
	to_scripts/install-build-tools.sh:40ba3a7d1e2572b17b3b6616e77a288e/raw/install-build-tools.sh \
	to_scripts/install-gtest.sh:cbb356377ed4ba4988940595e4e7789c/raw/install-gtest.sh \
	to_scripts/install-dpdk.sh:9a41343ec02beb86fbdb22c7a4f8794e/raw/install-dpdk.sh \
	to_scripts/install-huge-pages.sh:4db079efc48db2e913ac75df5000d577/raw/install-huge-pages.sh

EXECUTABLE_FILES := \
	to_home_dir/force-clean-repo.sh \
	to_scripts/test-24-bit-color.sh \
	to_scripts/install-build-tools.sh \
	to_scripts/install-gtest.sh \
	to_scripts/install-dpdk.sh \
	to_scripts/install-huge-pages.sh

# Non-destructive: report which files differ from their gist, and which way.
check-gists:
	@tmp=$$(mktemp -d); drift=0; \
	for entry in $(GIST_FILES); do \
		path=$${entry%%:*}; url=$${entry#*:}; \
		curl -fsSL "$(GIST_BASE)/$$url" -o "$$tmp/f" || { printf '%-34s FETCH FAILED\n' "$$path"; continue; }; \
		if cmp -s "$$tmp/f" "$$path"; then \
			printf '%-34s in sync\n' "$$path"; \
		else \
			printf '%-34s DRIFTED (repo %+d lines vs gist)\n' "$$path" \
				"$$(( $$(wc -l < "$$path") - $$(wc -l < "$$tmp/f") ))"; \
			drift=1; \
		fi; \
	done; \
	rm -rf "$$tmp"; \
	if [ "$$drift" = 1 ]; then \
		echo ""; \
		echo "Drift found. This repo is the source of truth — push the repo copy up to"; \
		echo "the gist, or run 'make pull-gists' only if you truly want the gist to win."; \
	fi

# Destructive: overwrite the repo copies from the gists. This is what the old
# 'update' target did unconditionally. Requires CONFIRM=yes so it cannot be run
# by reflex or by a script that just wanted fresh files.
pull-gists:
	@if [ "$(CONFIRM)" != "yes" ]; then \
		echo "REFUSING: this OVERWRITES repo files from the gists and can revert committed work."; \
		echo "Run 'make check-gists' first. To proceed: make pull-gists CONFIRM=yes"; \
		exit 1; \
	fi
	@for entry in $(GIST_FILES); do \
		path=$${entry%%:*}; url=$${entry#*:}; \
		echo "pulling $$path"; \
		wget -q --show-progress "$(GIST_BASE)/$$url" -O "$$path"; \
	done
	chmod +x $(EXECUTABLE_FILES)

# Kept so muscle memory and old notes fail loudly instead of destroying work.
update:
	@echo "'make update' used to overwrite repo files from gists and has been removed."
	@echo "  make check-gists   report drift (safe)"
	@echo "  make pull-gists CONFIRM=yes   overwrite repo FROM gists (destructive)"
	@exit 1

.PHONY: help all build prepare clean update check-gists pull-gists print-version

