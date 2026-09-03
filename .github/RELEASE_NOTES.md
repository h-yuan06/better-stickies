### Install

1. Download the zip below, unzip it, and drag **Better Stickies.app** to `/Applications`.
2. This build is **not signed with an Apple Developer ID**, so Gatekeeper will refuse
   it on first launch. Clear the quarantine flag once:

```
xattr -dr com.apple.quarantine "/Applications/Better Stickies.app"
```

3. Launch it. The app lives in the menu bar — there is no Dock icon.

Updates after this arrive automatically and are verified with an EdDSA signature, so
you only need to do the step above once.

**Requires macOS 26 or later.**
