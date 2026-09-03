#!/usr/bin/env bash
# Re-resolves Swift package dependencies and updates the committed pin file.
#
# Run this deliberately, review the diff, and commit it. Builds otherwise refuse to
# resolve anything, so dependencies cannot drift silently between machines or runs.
set -euo pipefail

cd "$(dirname "$0")/.."
DERIVED_DATA="${DERIVED_DATA:-$HOME/Library/Developer/BetterStickies/DerivedData}"

Scripts/bootstrap.sh >/dev/null

xcodebuild \
  -project BetterStickies.xcodeproj \
  -scheme BetterStickies \
  -derivedDataPath "$DERIVED_DATA" \
  -clonedSourcePackagesDirPath "$DERIVED_DATA/SourcePackages" \
  -resolvePackageDependencies

cp BetterStickies.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved Package.resolved
echo
echo "Package.resolved updated:"
git --no-pager diff --stat Package.resolved || true
