#!/usr/bin/env bash
# Ad-hoc signs an app bundle from the inside out.
#
# There is no Developer ID for this project, so update integrity comes from Sparkle's
# EdDSA signatures rather than Apple's. Signing still matters: nested code must be
# sealed before its container, or the outer signature is invalid the moment it is
# written. Hardened runtime is deliberately NOT enabled — it would turn on Library
# Validation, which refuses to load an ad-hoc signed Sparkle.framework.
set -euo pipefail

APP="${1:?usage: adhoc-sign.sh <path to .app> [entitlements.plist]}"
ENTITLEMENTS="${2:-}"

# iCloud-synced folders stamp com.apple.FinderInfo on bundle directories, which
# codesign rejects outright with "resource fork, Finder information, or similar
# detritus not allowed".
xattr -cr "$APP"

FRAMEWORK="$APP/Contents/Frameworks/Sparkle.framework"
if [[ -d "$FRAMEWORK" ]]; then
  echo "==> Signing Sparkle (inside out)"
  for xpc in "$FRAMEWORK"/Versions/B/XPCServices/*.xpc; do
    [[ -e "$xpc" ]] || continue
    codesign --force --sign - --timestamp=none "$xpc"
  done
  codesign --force --sign - --timestamp=none "$FRAMEWORK/Versions/B/Autoupdate"
  codesign --force --sign - --timestamp=none "$FRAMEWORK/Versions/B/Updater.app"
  codesign --force --sign - --timestamp=none "$FRAMEWORK/Versions/B"
fi

echo "==> Signing app"
# Clear again: signing the nested code can take long enough for a file provider to
# re-stamp the bundle root in the meantime.
xattr -c "$APP" 2>/dev/null || true
if [[ -n "$ENTITLEMENTS" && -f "$ENTITLEMENTS" ]]; then
  codesign --force --sign - --timestamp=none --entitlements "$ENTITLEMENTS" "$APP"
else
  codesign --force --sign - --timestamp=none "$APP"
fi

echo "==> Verifying"
codesign --verify --deep --strict --verbose=2 "$APP"
echo "Signed: $APP"
