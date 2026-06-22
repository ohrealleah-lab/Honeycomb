APP_NAME=SoliBee
APP_BUNDLE=$(APP_NAME).app
MACOS_BIN=$(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)

.PHONY: all build clean test run

all: build

build:
	# Build the executable using Swift Package Manager
	swift build
	# Create standalone application bundle structure
	mkdir -p $(APP_BUNDLE)/Contents/MacOS
	mkdir -p $(APP_BUNDLE)/Contents/Resources
	cp src/Info.plist $(APP_BUNDLE)/Contents/Info.plist
	cp src/AppIcon.icns $(APP_BUNDLE)/Contents/Resources/AppIcon.icns
	cp src/priest.png $(APP_BUNDLE)/Contents/Resources/priest.png
	cp src/moogle.jpg $(APP_BUNDLE)/Contents/Resources/moogle.jpg
	cp src/dingwall.jpg $(APP_BUNDLE)/Contents/Resources/dingwall.jpg
	cp J.png $(APP_BUNDLE)/Contents/Resources/J.png
	cp Q.png $(APP_BUNDLE)/Contents/Resources/Q.png
	cp K.png $(APP_BUNDLE)/Contents/Resources/K.png
	cp src/shuffle.aiff $(APP_BUNDLE)/Contents/Resources/shuffle.aiff
	cp src/snap.aiff $(APP_BUNDLE)/Contents/Resources/snap.aiff
	cp src/victory.aiff $(APP_BUNDLE)/Contents/Resources/victory.aiff
	# Copy compiled binary from SPM build path to the app bundle
	cp .build/debug/$(APP_NAME) $(MACOS_BIN)
	chmod +x $(MACOS_BIN)
	@echo "Build successful! $(APP_BUNDLE) created."

clean:
	swift package clean
	rm -rf $(APP_BUNDLE)
	rm -rf .build
	rm -f test_runner

test:
	# Compile test runner excluding SoliBeeApp.swift (which has the GUI @main entry)
	swiftc -o test_runner -sdk $$(xcrun --show-sdk-path) -target arm64-apple-macos14.0 src/Models/*.swift src/ViewModels/*.swift src/Views/*.swift src/Beecell/Models/*.swift src/Beecell/ViewModels/*.swift src/Beecell/Views/*.swift src/Spider/Models/*.swift src/Spider/ViewModels/*.swift src/Spider/Views/*.swift SoliBeeTests/*.swift
	# Run tests
	./test_runner
	# Cleanup test runner binary
	rm -f test_runner

run: build
	open $(APP_BUNDLE)
