#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if (( $# != 1 )); then
  print -u2 "Usage: ./scripts/release.sh <major.minor.patch>"
  exit 1
fi

version="${1#v}"
tag="v$version"

if [[ ! "$version" =~ '^[0-9]+\.[0-9]+\.[0-9]+$' ]]; then
  print -u2 "Version must use semantic versioning, for example: 1.3.0"
  exit 1
fi

if [[ "$(git branch --show-current)" != "main" ]]; then
  print -u2 "Releases must be created from the main branch"
  exit 1
fi

if [[ -n "$(git status --porcelain)" ]]; then
  print -u2 "Working tree must be clean before creating a release"
  exit 1
fi

git fetch --tags origin main
if [[ "$(git rev-parse HEAD)" != "$(git rev-parse origin/main)" ]]; then
  print -u2 "Local main must exactly match origin/main"
  exit 1
fi

if git rev-parse -q --verify "refs/tags/$tag" >/dev/null; then
  print -u2 "Tag already exists: $tag"
  exit 1
fi

current_build="$(plutil -extract CFBundleVersion raw Resources/Info.plist)"
next_build="$((current_build + 1))"
plutil -replace CFBundleShortVersionString -string "$version" Resources/Info.plist
plutil -replace CFBundleVersion -string "$next_build" Resources/Info.plist

./scripts/verify-all.sh
MOSS_ARCHS="$(uname -m)" MOSS_VERSION="$version" MOSS_BUILD_NUMBER="$next_build" ./scripts/build-app.sh

git add Resources/Info.plist
git commit -m "chore: release $tag"
git tag -a "$tag" -m "Moss $version"
git push --atomic origin main "$tag"

echo "Release triggered: https://github.com/Arlic-Festoken/moss-focus-island/releases/tag/$tag"
