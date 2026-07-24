APP_NAME=Honeycomb
APP_BUNDLE=$(APP_NAME).app
MACOS_BIN=$(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)

# Platform-agnostic game logic lives in ../shared (compiled by both the macOS and iOS
# apps); mac-only code stays under src/. Both lists feed the flat swiftc compiles below.
SHARED_SRCS=../shared/Models/*.swift ../shared/ViewModels/*.swift ../shared/Beecell/Models/*.swift ../shared/Beecell/ViewModels/*.swift ../shared/Spider/Models/*.swift ../shared/Spider/ViewModels/*.swift ../shared/Blackjack/Models/*.swift ../shared/Blackjack/ViewModels/*.swift ../shared/VideoPoker/Models/*.swift ../shared/VideoPoker/ViewModels/*.swift ../shared/Honeycomb/Models/*.swift ../shared/Honeycomb/ViewModels/*.swift
MAC_SRCS=src/Models/*.swift src/Views/*.swift src/Beecell/Views/*.swift src/Spider/Views/*.swift src/Blackjack/Views/*.swift src/VideoPoker/Views/*.swift src/Honeycomb/Views/*.swift src/Debug/*.swift

.PHONY: all build clean test run bridge

all: build

build:
	# Build the executable using Swift Package Manager (release) — package root is the
	# repo root so the target can compile ../shared alongside src/
	swift build -c release --package-path ..
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
	cp "images/backgrounds/Forest.png" "$(APP_BUNDLE)/Contents/Resources/Forest.png"
	cp "images/backgrounds/On The Water.png" "$(APP_BUNDLE)/Contents/Resources/On The Water.png"
	cp "images/backgrounds/Pareidolic.png" "$(APP_BUNDLE)/Contents/Resources/Pareidolic.png"
	cp "images/backgrounds/Pareidolic 2.png" "$(APP_BUNDLE)/Contents/Resources/Pareidolic 2.png"
	cp "images/backgrounds/Red Sky.png" "$(APP_BUNDLE)/Contents/Resources/Red Sky.png"
	cp "images/backgrounds/Sunset.png" "$(APP_BUNDLE)/Contents/Resources/Sunset.png"
	cp src/shuffle.aiff $(APP_BUNDLE)/Contents/Resources/shuffle.aiff
	cp src/snap.aiff $(APP_BUNDLE)/Contents/Resources/snap.aiff
	cp src/victory.aiff $(APP_BUNDLE)/Contents/Resources/victory.aiff
	# Copy compiled binary from SPM build path (at the repo root) to the app bundle
	cp ../.build/release/$(APP_NAME) $(MACOS_BIN)
	chmod +x $(MACOS_BIN)
	# Sign the app bundle so macOS doesn't kill it on launch
	codesign --force --deep --sign - $(APP_BUNDLE)
	@echo "Build successful! $(APP_BUNDLE) created."

clean:
	swift package clean --package-path ..
	rm -rf $(APP_BUNDLE)
	rm -rf .build ../.build
	rm -f test_runner

test:
	# Compile test runner excluding SoliBeeApp.swift (which has the GUI @main entry)
	swiftc -o test_runner -sdk $$(xcrun --show-sdk-path) -target arm64-apple-macos14.0 $(SHARED_SRCS) $(MAC_SRCS) SoliBeeTests/*.swift
	# Run tests
	./test_runner
	# Cleanup test runner binary
	rm -f test_runner

bridge:
	# Compile the Universal Agent Bridge
	swiftc -o solibee_bridge -sdk $$(xcrun --show-sdk-path) -target arm64-apple-macos14.0 $(SHARED_SRCS) $(MAC_SRCS) SoliBeeBridge/UniversalBridge.swift

run: build
	open $(APP_BUNDLE)
