#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

/Library/Developer/CommandLineTools/usr/bin/swiftc \
  -typecheck \
  -parse-as-library \
  "$ROOT"/Sources/Moss/*.swift \
  -sdk /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk \
  -target arm64-apple-macosx14.0 \
  -framework SwiftUI \
  -framework AppKit \
  -framework Charts \
  -module-name Moss
