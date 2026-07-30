#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EXECUTABLE="$(mktemp /tmp/moss-companion-check.XXXXXX)"
SDK="${SDK:-$(xcrun --sdk macosx --show-sdk-path)}"
SWIFTC="${SWIFTC:-$(xcrun --find swiftc)}"
ARCH="${MOSS_NATIVE_ARCH:-$(uname -m)}"

cleanup() {
  rm -f "$EXECUTABLE"
}
trap cleanup EXIT

SOURCES=("$ROOT"/Sources/Moss/*.swift)
SOURCES=(${SOURCES:#"$ROOT/Sources/Moss/MossApp.swift"})

"$SWIFTC" \
  -parse-as-library \
  "$ROOT/Tests/MossCompanionBehaviorCheck.swift" \
  "${SOURCES[@]}" \
  -sdk "$SDK" \
  -target "$ARCH-apple-macosx14.0" \
  -framework SwiftUI \
  -framework AppKit \
  -framework Charts \
  -framework CloudKit \
  -framework CryptoKit \
  -framework PDFKit \
  -module-name MossCompanionBehaviorCheck \
  -o "$EXECUTABLE"

"$EXECUTABLE"
