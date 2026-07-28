#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SDK="${SDK:-$(xcrun --sdk macosx --show-sdk-path)}"
SWIFTC="${SWIFTC:-$(xcrun --find swiftc)}"
ARCH="${MOSS_NATIVE_ARCH:-$(uname -m)}"

"$SWIFTC" \
  -typecheck \
  -parse-as-library \
  "$ROOT"/Sources/Moss/*.swift \
  -sdk "$SDK" \
  -target "$ARCH-apple-macosx14.0" \
  -framework SwiftUI \
  -framework AppKit \
  -framework Charts \
  -module-name Moss
