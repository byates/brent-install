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
	-@cp -r to_usr_bin/.  $(BUILD_DIR)/usr/share/$(PACKAGE_NAME)/scripts/ 2>/dev/null || true
	cp setup.sh $(BUILD_DIR)/usr/share/$(PACKAGE_NAME)/scripts/

clean:
	rm -rf $(BUILD_DIR)
	rm -f $(DEB_FILE)

install: build
	sudo dpkg -i $(DEB_FILE)

.PHONY: all build prepare clean install

