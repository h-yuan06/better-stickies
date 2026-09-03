# Better Stickies

A sticky notes app for macOS that stays out of your way and in front of your windows.

Built because Apple's Stickies loses on four counts: it occupies a Dock icon, its
notes disappear behind full-screen windows, it has no checklists, and its chrome is
twenty years old.

## What it does

- **Genuinely always on top.** Notes float above other apps' full-screen spaces, not
  just above ordinary windows — using AppKit's `canJoinAllApplications` collection
  behavior, which is the sanctioned mechanism for exactly this.
- **Real Liquid Glass.** Apple's `glassEffect` APIs, with the tint colour, tint
  strength, glass style and opacity all adjustable in Settings — globally, or per note.
- **Rich text that includes checklists.** Bold, italic, underline, strikethrough,
  bulleted lists, numbered lists that renumber themselves, and checklists with
  clickable boxes. Tab and Shift-Tab nest; Return continues a list and steps out of it
  when the item is empty.
- **A background app.** It lives in the menu bar. No Dock icon, no ⌘-Tab entry.
- **Quick capture.** ⌥⌘N spawns a note under the pointer from anywhere, with no
  Accessibility permission prompt.

Requires **macOS 26 or later**.

## Install

Grab the latest zip from [Releases](../../releases), unzip, and drag the app to
`/Applications`. Then, once:

```
xattr -dr com.apple.quarantine "/Applications/Better Stickies.app"
```

This is necessary because the app is not signed with an Apple Developer ID — that
costs $99/year, and this project does not have one. Updates after the first launch are
automatic and are verified with an EdDSA signature, so you only do this once.

## Building

```
Scripts/bootstrap.sh
open BetterStickies.xcodeproj
```

`bootstrap.sh` downloads pinned copies of XcodeGen and Sparkle's tools into `.tools/`
and generates the Xcode project from `project.yml`. The `.xcodeproj` is **not**
committed — `project.yml` is the single source of truth, so it can never drift.

Dependency versions are pinned in `Package.resolved` at the repo root, rather than
inside the generated `.xcodeproj` where Xcode normally keeps it. `bootstrap.sh` copies
it into place, and every build runs with resolution disabled, so a dependency cannot
move underneath you without the pin file changing in a reviewable commit. To move a
pin deliberately:

```
Scripts/update-dependencies.sh
```

To produce a signed, zipped build:

```
ARCHS=arm64 Scripts/package.sh
```

Note that build products go to `~/Library/Developer/BetterStickies/DerivedData`,
deliberately outside the repo: on an iCloud-synced folder the file provider stamps
`com.apple.FinderInfo` onto bundle directories, and `codesign` refuses to sign those.

## Testing

```
Scripts/test.sh
```

Run it through the script rather than calling `xcodebuild` directly: it puts
DerivedData outside the repo, which matters for the iCloud reason described above.

The suite covers list editing semantics, numbering across nesting levels, document
serialization round-trips, storage durability including corrupt-file recovery, and
window frame clamping.

## Releasing

One-time setup:

1. `Scripts/generate-keys.sh` and follow its instructions to set the
   `SPARKLE_PRIVATE_KEY` and `SPARKLE_PUBLIC_KEY` repository secrets.
2. Enable GitHub Pages for the `gh-pages` branch.

Then every release is just:

```
git tag v0.2.0 && git push --tags
```

CI builds a universal binary, ad-hoc signs it, signs the archive with your EdDSA key,
publishes a GitHub release, and updates the appcast on `gh-pages`.

## Architecture notes

A few decisions that are not obvious from the file names:

- **Notes are stored in a hand-written document format**, not a `Codable`
  `AttributedString`. `AttributedString`'s `Codable` conformance was measured to
  silently drop `underlineStyle` while preserving `NSFont`, and its dynamic-member
  lookup routes some attributes into SwiftUI's attribute scope and others into
  AppKit's. Silently losing formatting is the worst possible failure mode for a notes
  app, so the format is explicit, versioned, and round-trip tested.
- **List markers are drawn, not inserted as text.** A custom `NSTextLayoutFragment`
  paints bullets, numbers and checkboxes in the gutter. Copying a note therefore
  yields clean text, and a checkbox is a real hit target rather than an attachment
  character that Backspace could delete.
- **Hardened runtime is deliberately off.** It would enable Library Validation, which
  refuses to load an ad-hoc signed `Sparkle.framework`. It is only required for
  notarization, which needs the Developer ID this project does not have.
- **Formatting shortcuts are handled in the text view**, not through a main menu,
  because note windows are non-activating panels — the app's menu bar is usually not
  frontmost, so menu key equivalents would never fire.
