#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DATA="$HOME/Library/Application Support/Moss/moss-data.json"
BACKUP="$(mktemp /tmp/moss-data-backup.XXXXXX)"
EXECUTABLE="$(mktemp /tmp/moss-behavior-check.XXXXXX)"
HAD_DATA=0
SDK="${SDK:-$(xcrun --sdk macosx --show-sdk-path)}"
SWIFTC="${SWIFTC:-$(xcrun --find swiftc)}"
ARCH="${MOSS_NATIVE_ARCH:-$(uname -m)}"

if [[ -f "$DATA" ]]; then
  cp "$DATA" "$BACKUP"
  HAD_DATA=1
fi

cleanup() {
  if [[ "$HAD_DATA" == "1" ]]; then
    mkdir -p "$(dirname "$DATA")"
    cp "$BACKUP" "$DATA"
  else
    rm -f "$DATA"
  fi
  rm -f "$BACKUP" "$EXECUTABLE"
}
trap cleanup EXIT

SOURCES=("$ROOT"/Sources/Moss/*.swift)
SOURCES=(${SOURCES:#"$ROOT/Sources/Moss/MossApp.swift"})

"$SWIFTC" \
  -parse-as-library \
  "$ROOT/Tests/MossBehaviorCheck.swift" \
  "${SOURCES[@]}" \
  -sdk "$SDK" \
  -target "$ARCH-apple-macosx14.0" \
  -framework SwiftUI \
  -framework AppKit \
  -framework Charts \
  -framework CloudKit \
  -framework CryptoKit \
  -framework PDFKit \
  -module-name MossBehaviorCheck \
  -o "$EXECUTABLE"

"$EXECUTABLE"
