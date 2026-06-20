#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SDK="/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk"
SWIFTC="/Library/Developer/CommandLineTools/usr/bin/swiftc"
BUILD="$ROOT/.build/manual"
APP="$ROOT/dist/Moss.app"
CONTENTS="$APP/Contents"

mkdir -p "$BUILD" "$CONTENTS/MacOS" "$CONTENTS/Resources"

"$SWIFTC" \
  -parse-as-library \
  -O \
  -o "$CONTENTS/MacOS/Moss" \
  "$ROOT"/Sources/Moss/*.swift \
  -sdk "$SDK" \
  -target arm64-apple-macosx14.0 \
  -framework SwiftUI \
  -framework AppKit \
  -framework Charts \
  -module-name Moss

cp "$ROOT/Resources/Info.plist" "$CONTENTS/Info.plist"

ICON_SOURCE="$ROOT/Resources/AppIcon.svg"
ICON_PNG="$BUILD/AppIcon-1024.png"
ICONSET="$BUILD/AppIcon.iconset"
rm -rf "$ICONSET"
mkdir -p "$ICONSET"

sips -s format png "$ICON_SOURCE" --out "$ICON_PNG" >/dev/null
for spec in \
  "16 icon_16x16.png" \
  "32 icon_16x16@2x.png" \
  "32 icon_32x32.png" \
  "64 icon_32x32@2x.png" \
  "128 icon_128x128.png" \
  "256 icon_128x128@2x.png" \
  "256 icon_256x256.png" \
  "512 icon_256x256@2x.png" \
  "512 icon_512x512.png" \
  "1024 icon_512x512@2x.png"
do
  size="${spec%% *}"
  name="${spec#* }"
  sips -z "$size" "$size" "$ICON_PNG" --out "$ICONSET/$name" >/dev/null
done

iconutil -c icns "$ICONSET" -o "$CONTENTS/Resources/AppIcon.icns"
codesign --force --deep --sign - "$APP" >/dev/null

echo "$APP"
