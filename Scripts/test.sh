#!/usr/bin/env bash
# Runs the test suite.
#
# DERIVED_DATA defaults outside the repo on purpose: this project often lives on an
# iCloud-synced Desktop, where the file provider stamps com.apple.FinderInfo onto
# bundle directories and codesign then refuses to sign the test bundle, failing the
# build for reasons that have nothing to do with the code.
set -euo pipefail

cd "$(dirname "$0")/.."
DERIVED_DATA="${DERIVED_DATA:-$HOME/Library/Developer/BetterStickies/DerivedData}"

Scripts/bootstrap.sh >/dev/null

exec xcodebuild \
  -project BetterStickies.xcodeproj \
  -scheme BetterStickies \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath "$DERIVED_DATA" \
  -clonedSourcePackagesDirPath "$DERIVED_DATA/SourcePackages" \
  -skipPackagePluginValidation \
  -skipMacroValidation \
  ONLY_ACTIVE_ARCH=YES \
  COMPILER_INDEX_STORE_ENABLE=NO \
  "$@" \
  test
