#!/usr/bin/env bash
# Generates the Sparkle EdDSA key pair used to sign updates. Run once, ever.
#
# The private key is what proves an update really came from you. Nothing else does:
# this app is not signed with an Apple Developer ID, so Sparkle's signature is the
# only integrity check between a download and your users.
set -euo pipefail

cd "$(dirname "$0")/.."
Scripts/bootstrap.sh >/dev/null

echo "==> Generating EdDSA key pair"
.tools/sparkle/bin/generate_keys

cat <<'NOTES'

Next steps
----------
1. The PRIVATE key was stored in your login Keychain as "Private key for signing
   Sparkle updates". Export it with:

       .tools/sparkle/bin/generate_keys -x sparkle_private_key.txt

   Add its contents as the repository secret SPARKLE_PRIVATE_KEY, then delete the
   file. It is already covered by .gitignore, but do not rely on that.

2. Add the PUBLIC key printed above as the repository secret SPARKLE_PUBLIC_KEY.
   The release workflow injects it into Info.plist at build time.

3. Enable GitHub Pages for the gh-pages branch so the appcast is reachable at
   the SUFeedURL in project.yml.

Losing the private key means you can never ship an update to existing installs
again — they will reject anything signed with a different key.
NOTES
