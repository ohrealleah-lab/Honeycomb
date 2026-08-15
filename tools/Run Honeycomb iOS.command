#!/bin/bash
# Double-click to build Honeycomb and launch it in the iOS Simulator.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="$REPO_ROOT/ios/Honeycomb.xcodeproj"
SCHEME="Honeycomb"
BUNDLE_ID="com.leah.Honeycomb"
LAST_DEVICE_FILE="$REPO_ROOT/ios/build/.last_simulator_udid"

cd "$REPO_ROOT"

echo "==> Available iOS simulators:"
# Only list devices under iOS runtime sections (skip watchOS/tvOS/visionOS), only iPhone/iPad.
DEVICE_LINES="$(xcrun simctl list devices available | awk '/-- iOS /{f=1;next} /^-- /{f=0} f' | grep -E 'iPhone|iPad')"

if [ -z "$DEVICE_LINES" ]; then
  echo "No iOS simulators found. Create one in Xcode > Settings > Platforms first."
  read -n 1 -s -r -p "Press any key to close..."
  exit 1
fi

NAMES=()
UDIDS=()
while IFS= read -r line; do
  NAME="$(echo "$line" | sed -E 's/^[[:space:]]*(.*) \([0-9A-F-]+\).*$/\1/')"
  ID="$(echo "$line" | grep -Eo '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}')"
  NAMES+=("$NAME")
  UDIDS+=("$ID")
done <<< "$DEVICE_LINES"

LAST_UDID=""
[ -f "$LAST_DEVICE_FILE" ] && LAST_UDID="$(cat "$LAST_DEVICE_FILE")"
DEFAULT_INDEX=1
FOUND_LAST=0
if [ -n "$LAST_UDID" ]; then
  for i in "${!UDIDS[@]}"; do
    if [ "${UDIDS[$i]}" = "$LAST_UDID" ]; then
      DEFAULT_INDEX=$((i + 1))
      FOUND_LAST=1
    fi
  done
fi

for i in "${!NAMES[@]}"; do
  NUM=$((i + 1))
  MARK=""
  [ "$FOUND_LAST" -eq 1 ] && [ "$NUM" -eq "$DEFAULT_INDEX" ] && MARK="  <- last used"
  printf "  %2d) %s%s\n" "$NUM" "${NAMES[$i]}" "$MARK"
done

read -r -p "Pick a simulator [1-${#NAMES[@]}] (Enter for #$DEFAULT_INDEX): " CHOICE
CHOICE="${CHOICE:-$DEFAULT_INDEX}"

if ! [[ "$CHOICE" =~ ^[0-9]+$ ]] || [ "$CHOICE" -lt 1 ] || [ "$CHOICE" -gt "${#NAMES[@]}" ]; then
  echo "Invalid choice."
  read -n 1 -s -r -p "Press any key to close..."
  exit 1
fi

DEVICE_NAME="${NAMES[$((CHOICE - 1))]}"
UDID="${UDIDS[$((CHOICE - 1))]}"
mkdir -p "$(dirname "$LAST_DEVICE_FILE")"
echo "$UDID" > "$LAST_DEVICE_FILE"
echo "==> Using: $DEVICE_NAME ($UDID)"

echo "==> Booting simulator ($UDID) if needed"
STATE="$(xcrun simctl list devices | grep -F "$UDID" | grep -Eo '\((Booted|Shutdown|Booting)\)' | tr -d '()')"
if [ "$STATE" != "Booted" ]; then
  xcrun simctl boot "$UDID"
fi
open -a Simulator --args -CurrentDeviceUDID "$UDID"

echo "==> Building Honeycomb (this can take a minute)"
BUILD_DIR="$REPO_ROOT/ios/build"
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Debug \
  -destination "id=$UDID" \
  -derivedDataPath "$BUILD_DIR" \
  build

APP_PATH="$(find "$BUILD_DIR/Build/Products" -maxdepth 2 -name "*.app" -print -quit)"
if [ -z "$APP_PATH" ]; then
  echo "Build succeeded but no .app was found under $BUILD_DIR/Build/Products"
  read -n 1 -s -r -p "Press any key to close..."
  exit 1
fi

echo "==> Installing $APP_PATH"
xcrun simctl install "$UDID" "$APP_PATH"

echo "==> Launching $BUNDLE_ID"
xcrun simctl launch "$UDID" "$BUNDLE_ID"

echo "==> Done."
read -n 1 -s -r -p "Press any key to close..."
