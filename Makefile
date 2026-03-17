PREFIX ?= /usr/local
APP_NAME = ClaudeNotifier
BINARY_NAME = claude-notifier
BUILD_DIR = build
APP_BUNDLE = $(BUILD_DIR)/$(APP_NAME).app

.PHONY: all build install uninstall clean icon

all: build

icon: Resources/AppIcon.icns

Resources/AppIcon.icns: Resources/claude-logo.png
	./generate-icon.sh

build: Sources/main.swift Info.plist
	@echo "==> Compiling $(BINARY_NAME)..."
	@mkdir -p $(BUILD_DIR)
	swiftc -O -o $(BUILD_DIR)/$(BINARY_NAME) Sources/main.swift
	@echo "==> Creating app bundle..."
	@mkdir -p $(APP_BUNDLE)/Contents/MacOS
	@mkdir -p $(APP_BUNDLE)/Contents/Resources
	@cp $(BUILD_DIR)/$(BINARY_NAME) $(APP_BUNDLE)/Contents/MacOS/$(BINARY_NAME)
	@cp Info.plist $(APP_BUNDLE)/Contents/Info.plist
	@if [ -f Resources/AppIcon.icns ]; then \
		cp Resources/AppIcon.icns $(APP_BUNDLE)/Contents/Resources/AppIcon.icns; \
	elif [ -x generate-icon.sh ]; then \
		./generate-icon.sh && cp Resources/AppIcon.icns $(APP_BUNDLE)/Contents/Resources/AppIcon.icns; \
	fi
	@codesign --force --sign - $(APP_BUNDLE)
	@echo "==> Build complete: $(APP_BUNDLE)"

install: build
	@echo "==> Installing to $(PREFIX)/bin/..."
	@mkdir -p $(PREFIX)/bin
	@rm -rf $(PREFIX)/bin/$(APP_NAME).app
	@cp -R $(APP_BUNDLE) $(PREFIX)/bin/$(APP_NAME).app
	@ln -sf $(PREFIX)/bin/$(APP_NAME).app/Contents/MacOS/$(BINARY_NAME) $(PREFIX)/bin/$(BINARY_NAME)
	@echo "==> Installed $(APP_NAME).app to $(PREFIX)/bin/"
	@echo "==> Symlinked $(BINARY_NAME) to $(PREFIX)/bin/$(BINARY_NAME)"

uninstall:
	@echo "==> Uninstalling..."
	@rm -rf $(PREFIX)/bin/$(APP_NAME).app
	@rm -f $(PREFIX)/bin/$(BINARY_NAME)
	@echo "==> Uninstalled."

clean:
	@rm -rf $(BUILD_DIR)
