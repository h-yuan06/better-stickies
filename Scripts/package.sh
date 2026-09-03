#!/usr/bin/env bash
# Builds a Release .app, ad-hoc signs it, and zips it into dist/.
#
#   Scripts/package.sh [version]
#
# ARCHS defaults to a universal binary; pass ARCHS=arm64 for a faster local build.
set -euo pipefail

cd "$(dirname "$0")/.."
VERSION="${1:-}"
ARCHS="${ARCHS:-arm64 x86_64}"
# Keep build products off iCloud-synced folders, which stamp xattrs codesign rejects.
DERIVED_DATA="${DERIVED_DATA:-$HOME/Library/Developer/BetterStickies/DerivedData}"
DIST="dist"
APP_NAME="Better Stickies"

Scripts/bootstrap.sh

echo "==> Building Release ($ARCHS)"
BUILD_ARGS=(
  -project BetterStickies.xcodeproj
  -scheme BetterStickies
  -configuration Release
  -derivedDataPath "$DERIVED_DATA"
  -clonedSourcePackagesDirPath "$DERIVED_DATA/SourcePackages"
  -skipPackagePluginValidation
  -skipMacroValidation
  ARCHS="$ARCHS"
  ONLY_ACTIVE_ARCH=NO
  COMPILER_INDEX_STORE_ENABLE=NO
)
[[ -n "$VERSION" ]] && BUILD_ARGS+=(MARKETING_VERSION="$VERSION")
# Sparkle orders releases by CFBundleVersion, so it must increase monotonically.
[[ -n "${BUILD_NUMBER:-}" ]] && BUILD_ARGS+=(CURRENT_PROJECT_VERSION="$BUILD_NUMBER")

xcodebuild "${BUILD_ARGS[@]}" build

APP="$DERIVED_DATA/Build/Products/Release/$APP_NAME.app"
[[ -d "$APP" ]] || { echo "Build produced no app at $APP"; exit 1; }

# Stage outside the working tree. On an iCloud-synced folder (Desktop, Documents)
# the file provider re-stamps com.apple.FinderInfo on bundle directories between
# clearing xattrs and signing, and codesign rejects the bundle for it.
STAGE="$DERIVED_DATA/stage"
rm -rf "$STAGE" "$DIST"
mkdir -p "$STAGE" "$DIST"
cp -R "$APP" "$STAGE/"
STAGED="$STAGE/$APP_NAME.app"

# The public key is injected here rather than committed, so the repo carries no
# release material and development builds honestly report "updates not configured".
if [[ -n "${SPARKLE_PUBLIC_KEY:-}" ]]; then
  echo "==> Injecting Sparkle public key"
  plutil -replace SUPublicEDKey -string "$SPARKLE_PUBLIC_KEY" "$STAGED/Contents/Info.plist"
fi

Scripts/adhoc-sign.sh "$STAGED" "Sources/App/BetterStickies.entitlements"

BUILT_VERSION=$(plutil -extract CFBundleShortVersionString raw "$STAGED/Contents/Info.plist")
ZIP="$DIST/BetterStickies-$BUILT_VERSION.zip"
echo "==> Zipping $ZIP"
ditto -c -k --sequesterRsrc --keepParent "$STAGED" "$ZIP"
# A copy of the .app is handy for local testing; only the zip is ever published.
ditto "$STAGED" "$DIST/$APP_NAME.app"

echo
echo "App: $DIST/$APP_NAME.app"
echo "Zip: $ZIP"
echo "Version: $BUILT_VERSION"
