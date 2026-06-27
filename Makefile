# Kai — developer workflow shortcuts.
# Cross-platform targets (test/build/cli) run anywhere Swift 6 is installed.
# App packaging targets (app/dmg/icon/run-app) require macOS.

.PHONY: build test release cli run-app app dmg icon clean

build:        ## Debug build of all libraries + executables
	swift build

test:         ## Run the full test suite
	swift test

release:      ## Release build of all products
	swift build -c release

cli:          ## Run the cross-platform demo
	swift run kai-cli

run-app:      ## Run the macOS app in development (macOS only)
	swift run kai-app

app:          ## Build dist/Kai.app (macOS only)
	./Scripts/build_app.sh

dmg: app      ## Build dist/Kai.dmg (macOS only)
	./Scripts/make_dmg.sh

icon:         ## Regenerate the app icon from App/AppIcon.svg (macOS only)
	./Scripts/generate_icon.sh

clean:
	swift package clean
	rm -rf dist
