#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DATA="$HOME/Library/Application Support/Moss/moss-data.json"
BACKUP="$(mktemp /tmp/moss-data-backup.XXXXXX)"
EXECUTABLE="$(mktemp /tmp/moss-behavior-check.XXXXXX)"
HAD_DATA=0

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

/Library/Developer/CommandLineTools/usr/bin/swiftc \
  -parse-as-library \
  "$ROOT/Tests/MossBehaviorCheck.swift" \
  "${SOURCES[@]}" \
  -sdk /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk \
  -target arm64-apple-macosx14.0 \
  -framework SwiftUI \
  -framework AppKit \
  -framework Charts \
  -module-name MossBehaviorCheck \
  -o "$EXECUTABLE"

"$EXECUTABLE"
