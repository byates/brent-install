# Default target
help:
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  help       Show this help message"
	@echo "  build      Build the Debian package"
	@echo "  clean      Remove generated files"
	@echo "  update     Download latest config and script files"

PACKAGE_NAME := brent-install
VERSION := 1.0
BUILD_DIR := $(PACKAGE_NAME)
DEB_FILE := $(PACKAGE_NAME)_$(VERSION).deb

all: build

build: prepare
	dpkg-deb --build $(BUILD_DIR) $(DEB_FILE)

prepare:
	@echo "Creating directory structure..."
	rm -rf $(BUILD_DIR)
	mkdir -p $(BUILD_DIR)/DEBIAN
	mkdir -p $(BUILD_DIR)/usr/share/$(PACKAGE_NAME)/to_home_dir
	mkdir -p $(BUILD_DIR)/usr/share/$(PACKAGE_NAME)/scripts

	@echo "Copying control file and scripts..."
	cp control $(BUILD_DIR)/DEBIAN/control
	cp postinst $(BUILD_DIR)/DEBIAN/postinst
	chmod 755 $(BUILD_DIR)/DEBIAN/postinst

	@echo "Copying files and setup script..."
	-@cp -r to_home_dir/. $(BUILD_DIR)/usr/share/$(PACKAGE_NAME)/to_home_dir/ 2>/dev/null || true
	-@cp -r to_scripts/.  $(BUILD_DIR)/usr/share/$(PACKAGE_NAME)/scripts/ 2>/dev/null || true
	cp setup.sh $(BUILD_DIR)/usr/share/$(PACKAGE_NAME)/scripts/

clean:
	rm -rf $(BUILD_DIR)
	rm -f $(DEB_FILE)

update:
	wget -q --show-progress https://gist.githubusercontent.com/byates/d04215a3dc88cf47015fea28d419e64e/raw/.tmux.conf -O ./to_home_dir/.tmux.conf
	wget -q --show-progress https://gist.githubusercontent.com/byates/d04215a3dc88cf47015fea28d419e64e/raw/.vimrc -O ./to_home_dir/.vimrc
	wget -q --show-progress https://gist.githubusercontent.com/byates/d04215a3dc88cf47015fea28d419e64e/raw/jby_bashrc.sh -O ./to_home_dir/.jby_bashrc.sh
	wget -q --show-progress https://gist.githubusercontent.com/byates/dd4f8dc9069c15f7cb2179df4dca78bc/raw/.gitconfig.inc -O ./to_home_dir/.gitconfig.inc
	wget -q --show-progress https://gist.githubusercontent.com/byates/d049f99a8e24cdcaf87752be414a18de/raw/force-clean-repo.sh -O ./to_home_dir/force-clean-repo.sh

	chmod +x ./to_home_dir/force-clean-repo.sh

	wget -q --show-progress https://gist.githubusercontent.com/byates/b6ded34f2c7436cac9898d92abb8a0d1/raw/test-24-bit-color.sh -O ./to_scripts/test-24-bit-color.sh
	wget -q --show-progress https://gist.githubusercontent.com/byates/40ba3a7d1e2572b17b3b6616e77a288e/raw/install-build-tools.sh -O ./to_scripts/install-build-tools.sh
	wget -q --show-progress https://gist.githubusercontent.com/byates/cbb356377ed4ba4988940595e4e7789c/raw/install-gtest.sh -O ./to_scripts/install-gtest.sh
	wget -q --show-progress https://gist.githubusercontent.com/byates/9a41343ec02beb86fbdb22c7a4f8794e/raw/install-dpdk.sh -O ./to_scripts/install-dpdk.sh
	wget -q --show-progress https://gist.githubusercontent.com/byates/4db079efc48db2e913ac75df5000d577/raw/install-huge-pages.sh -O ./to_scripts/install-huge-pages.sh

	chmod +x ./to_scripts/test-24-bit-color.sh
	chmod +x ./to_scripts/install-build-tools.sh
	chmod +x ./to_scripts/install-gtest.sh
	chmod +x ./to_scripts/install-dpdk.sh
	chmod +x ./to_scripts/install-huge-pages.sh

.PHONY: help all build prepare clean update

