#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SDK="${SDK:-$(xcrun --sdk macosx --show-sdk-path)}"
SWIFTC="${SWIFTC:-$(xcrun --find swiftc)}"
ARCH_LIST="${MOSS_ARCHS:-$(uname -m)}"
ARCHS=(${=ARCH_LIST})
BUILD="$ROOT/.build/manual"
APP="$ROOT/dist/Moss.app"
CONTENTS="$APP/Contents"

rm -rf "$APP"
mkdir -p "$BUILD" "$CONTENTS/MacOS" "$CONTENTS/Resources"

BINARIES=()
for arch in "${ARCHS[@]}"; do
  binary="$BUILD/Moss-$arch"
  "$SWIFTC" \
    -parse-as-library \
    -O \
    -o "$binary" \
    "$ROOT"/Sources/Moss/*.swift \
    -sdk "$SDK" \
    -target "$arch-apple-macosx14.0" \
    -framework SwiftUI \
    -framework AppKit \
    -framework Charts \
    -module-name Moss
  BINARIES+=("$binary")
done

if (( ${#BINARIES[@]} == 1 )); then
  cp "$BINARIES[1]" "$CONTENTS/MacOS/Moss"
else
  xcrun lipo -create "${BINARIES[@]}" -output "$CONTENTS/MacOS/Moss"
fi

cp "$ROOT/Resources/Info.plist" "$CONTENTS/Info.plist"
if [[ -n "${MOSS_VERSION:-}" ]]; then
  plutil -replace CFBundleShortVersionString -string "$MOSS_VERSION" "$CONTENTS/Info.plist"
fi
if [[ -n "${MOSS_BUILD_NUMBER:-}" ]]; then
  plutil -replace CFBundleVersion -string "$MOSS_BUILD_NUMBER" "$CONTENTS/Info.plist"
fi

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
