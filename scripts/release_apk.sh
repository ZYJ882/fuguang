#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PUBSPEC="$PROJECT_ROOT/pubspec.yaml"
FLUTTER_BIN="${FLUTTER_BIN:-flutter}"

current_version="$(grep -E '^version:' "$PUBSPEC" | awk '{print $2}')"
if [[ ! "$current_version" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)\+([0-9]+)$ ]]; then
  echo "Unsupported version format: $current_version" >&2
  exit 1
fi

major="${BASH_REMATCH[1]}"
minor="${BASH_REMATCH[2]}"
patch="${BASH_REMATCH[3]}"
build="${BASH_REMATCH[4]}"
next_version="${major}.${minor}.$((patch + 1))+$((build + 1))"

sed -i -E "s/^version: .*/version: ${next_version}/" "$PUBSPEC"
echo "Version bumped: ${current_version} -> ${next_version}"

cd "$PROJECT_ROOT"
python3 scripts/generate_android_icons.py
"$FLUTTER_BIN" pub get
"$FLUTTER_BIN" build apk --release --android-skip-build-dependency-validation

echo "Release APK: $PROJECT_ROOT/build/app/outputs/flutter-apk/app-release.apk"
