# TunnelGuard — Build & Package Automation
# Usage:
#   make build       — Build release .app
#   make dmg         — Create distributable DMG
#   make clean       — Remove build artifacts
#   make all         — Build + DMG

SCHEME       = TunnelGuard
PROJECT      = TunnelGuard.xcodeproj
CONFIG       = Release
DERIVED      = $(HOME)/Library/Developer/Xcode/DerivedData
DMG_NAME     = TunnelGuard
DMG_OUT      = $(CURDIR)/dist/$(DMG_NAME).dmg
DMG_TMP      = /tmp/tunnelguard-dmg-build
APP_FIND     = $(shell find $(DERIVED)/TunnelGuard-*/Build/Products/$(CONFIG) -name "TunnelGuard.app" -maxdepth 1 2>/dev/null | head -1)
VERSION      = $(shell grep -m1 'MARKETING_VERSION' $(PROJECT)/project.pbxproj | sed 's/.*= //' | sed 's/;.*//')
BUILD_NUM    = $(shell grep -m1 'CURRENT_PROJECT_VERSION' $(PROJECT)/project.pbxproj | sed 's/.*= //' | sed 's/;.*//')

.PHONY: all build dmg clean info

all: build dmg

info:
	@echo "TunnelGuard v$(VERSION) ($(BUILD_NUM))"

build:
	@echo "Building TunnelGuard v$(VERSION) ($(BUILD_NUM)) — $(CONFIG)..."
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIG) build
	@echo "Build complete."

dmg: build
	@echo "Creating DMG..."
	@mkdir -p dist
	@rm -rf $(DMG_TMP) $(DMG_OUT)
	@mkdir -p $(DMG_TMP)
	@cp -R "$(APP_FIND)" $(DMG_TMP)/
	@ln -s /Applications $(DMG_TMP)/Applications
	hdiutil create -volname "$(DMG_NAME) v$(VERSION)" -srcfolder $(DMG_TMP) -ov -format UDZO "$(DMG_OUT)"
	@rm -rf $(DMG_TMP)
	@echo "DMG created: $(DMG_OUT)"
	@ls -lh "$(DMG_OUT)"

clean:
	@echo "Cleaning..."
	@rm -rf .build dist
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) clean 2>/dev/null || true
	@echo "Clean complete."
