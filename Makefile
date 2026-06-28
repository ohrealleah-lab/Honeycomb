APP_NAME=SoliBee
APP_BUNDLE=$(APP_NAME).app
MACOS_BIN=$(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)

.PHONY: all build clean test run

all: build

build:
	# Build the executable using Swift Package Manager (release)
	swift build -c release
	# Create standalone application bundle structure
	mkdir -p $(APP_BUNDLE)/Contents/MacOS
	mkdir -p $(APP_BUNDLE)/Contents/Resources
	cp src/Info.plist $(APP_BUNDLE)/Contents/Info.plist
	cp src/AppIcon.icns $(APP_BUNDLE)/Contents/Resources/AppIcon.icns
	cp src/priest.png $(APP_BUNDLE)/Contents/Resources/priest.png
	cp src/moogle.jpg $(APP_BUNDLE)/Contents/Resources/moogle.jpg
	cp src/dingwall.jpg $(APP_BUNDLE)/Contents/Resources/dingwall.jpg
	cp images/letters/Parisienne-Regular.ttf $(APP_BUNDLE)/Contents/Resources/Parisienne-Regular.ttf
	cp images/letters/LilyScriptOne-Regular.ttf $(APP_BUNDLE)/Contents/Resources/LilyScriptOne-Regular.ttf
	cp KaushanScript-Regular.ttf $(APP_BUNDLE)/Contents/Resources/KaushanScript-Regular.ttf
	cp DancingScript-VariableFont_wght.ttf $(APP_BUNDLE)/Contents/Resources/DancingScript-VariableFont_wght.ttf
	cp "images/backgrounds/Forest.png" "$(APP_BUNDLE)/Contents/Resources/Forest.png"
	cp "images/backgrounds/On The Water.png" "$(APP_BUNDLE)/Contents/Resources/On The Water.png"
	cp "images/backgrounds/Pareidolic.png" "$(APP_BUNDLE)/Contents/Resources/Pareidolic.png"
	cp "images/backgrounds/Pareidolic 2.png" "$(APP_BUNDLE)/Contents/Resources/Pareidolic 2.png"
	cp "images/backgrounds/Red Sky.png" "$(APP_BUNDLE)/Contents/Resources/Red Sky.png"
	cp "images/backgrounds/Sunset.png" "$(APP_BUNDLE)/Contents/Resources/Sunset.png"
	cp src/shuffle.aiff $(APP_BUNDLE)/Contents/Resources/shuffle.aiff
	cp src/snap.aiff $(APP_BUNDLE)/Contents/Resources/snap.aiff
	cp src/victory.aiff $(APP_BUNDLE)/Contents/Resources/victory.aiff
	# Copy compiled binary from SPM build path to the app bundle
	cp .build/release/$(APP_NAME) $(MACOS_BIN)
	chmod +x $(MACOS_BIN)
	# Sign the app bundle so macOS doesn't kill it on launch
	codesign --force --deep --sign - $(APP_BUNDLE)
	@echo "Build successful! $(APP_BUNDLE) created."

clean:
	swift package clean
	rm -rf $(APP_BUNDLE)
	rm -rf .build
	rm -f test_runner

test:
	# Compile test runner excluding SoliBeeApp.swift (which has the GUI @main entry)
	swiftc -o test_runner -sdk $$(xcrun --show-sdk-path) -target arm64-apple-macos14.0 src/Models/*.swift src/ViewModels/*.swift src/Views/*.swift src/Beecell/Models/*.swift src/Beecell/ViewModels/*.swift src/Beecell/Views/*.swift src/Spider/Models/*.swift src/Spider/ViewModels/*.swift src/Spider/Views/*.swift src/Blackjack/Models/*.swift src/Blackjack/ViewModels/*.swift src/Blackjack/Views/*.swift src/VideoPoker/Models/*.swift src/VideoPoker/ViewModels/*.swift src/VideoPoker/Views/*.swift SoliBeeTests/*.swift
	# Run tests
	./test_runner
	# Cleanup test runner binary
	rm -f test_runner

run: build
	open $(APP_BUNDLE)
