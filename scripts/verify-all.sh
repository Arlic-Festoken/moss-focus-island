#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

"$ROOT/scripts/typecheck.sh"
"$ROOT/scripts/behavior-check.sh"
"$ROOT/scripts/companion-behavior-check.sh"
"$ROOT/scripts/ui-regression-check.sh"

echo "All Moss checks passed"
