#!/usr/bin/env bash
# Downloads the pinned build tools into .tools/. Safe to re-run; skips what exists.
set -euo pipefail

cd "$(dirname "$0")/.."
TOOLS=".tools"
XCODEGEN_VERSION="2.46.0"
SPARKLE_VERSION="2.9.6"

mkdir -p "$TOOLS"

if [[ ! -x "$TOOLS/xcodegen/bin/xcodegen" ]]; then
  echo "==> XcodeGen $XCODEGEN_VERSION"
  curl -sSL -o "$TOOLS/xcodegen.zip" \
    "https://github.com/yonaskolb/XcodeGen/releases/download/$XCODEGEN_VERSION/xcodegen.zip"
  unzip -oq "$TOOLS/xcodegen.zip" -d "$TOOLS"
  rm -f "$TOOLS/xcodegen.zip"
  xattr -dr com.apple.quarantine "$TOOLS/xcodegen" 2>/dev/null || true
fi

# sign_update and generate_appcast ship in the Sparkle release tarball, not in the
# Swift package, so they are fetched separately and only needed at release time.
if [[ ! -x "$TOOLS/sparkle/bin/sign_update" ]]; then
  echo "==> Sparkle tools $SPARKLE_VERSION"
  curl -sSL -o "$TOOLS/sparkle.tar.xz" \
    "https://github.com/sparkle-project/Sparkle/releases/download/$SPARKLE_VERSION/Sparkle-$SPARKLE_VERSION.tar.xz"
  mkdir -p "$TOOLS/sparkle"
  tar -xJf "$TOOLS/sparkle.tar.xz" -C "$TOOLS/sparkle"
  rm -f "$TOOLS/sparkle.tar.xz"
  xattr -dr com.apple.quarantine "$TOOLS/sparkle" 2>/dev/null || true
fi

echo "==> Generating Xcode project"
"$TOOLS/xcodegen/bin/xcodegen" generate --quiet
echo "Ready."
