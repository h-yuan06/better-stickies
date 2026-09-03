#!/usr/bin/env python3
"""Add or replace one release in a Sparkle appcast.

generate_appcast rebuilds a feed from whatever archives are sitting in a folder,
which is awkward in CI where each run only has the archive it just built. This
edits the published feed in place instead: idempotent, and it never drops history.
"""
from __future__ import annotations

import argparse
import os
import xml.etree.ElementTree as ET
from email.utils import format_datetime
from datetime import datetime, timezone

SPARKLE_NS = "http://www.andymatuschak.org/xml-namespaces/sparkle"
ET.register_namespace("sparkle", SPARKLE_NS)


def empty_feed(title: str) -> ET.ElementTree:
    rss = ET.Element("rss", {"version": "2.0"})
    channel = ET.SubElement(rss, "channel")
    ET.SubElement(channel, "title").text = title
    return ET.ElementTree(rss)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--appcast", required=True, help="feed to edit, created if absent")
    parser.add_argument("--version", required=True, help="CFBundleShortVersionString")
    parser.add_argument("--build", required=True, help="CFBundleVersion")
    parser.add_argument("--url", required=True, help="download URL for the zip")
    parser.add_argument("--length", required=True, help="zip size in bytes")
    parser.add_argument("--signature", required=True, help="EdDSA signature from sign_update")
    parser.add_argument("--min-system", default="26.0")
    parser.add_argument("--release-notes-link", default="")
    parser.add_argument("--title", default="Better Stickies")
    args = parser.parse_args()

    if os.path.exists(args.appcast) and os.path.getsize(args.appcast) > 0:
        tree = ET.parse(args.appcast)
    else:
        tree = empty_feed(args.title)

    channel = tree.getroot().find("channel")
    if channel is None:
        channel = ET.SubElement(tree.getroot(), "channel")
        ET.SubElement(channel, "title").text = args.title

    # Re-running a release must update its entry, not append a duplicate.
    for item in channel.findall("item"):
        version = item.findtext(f"{{{SPARKLE_NS}}}shortVersionString")
        if version == args.version:
            channel.remove(item)

    item = ET.Element("item")
    ET.SubElement(item, "title").text = f"Version {args.version}"
    ET.SubElement(item, f"{{{SPARKLE_NS}}}version").text = args.build
    ET.SubElement(item, f"{{{SPARKLE_NS}}}shortVersionString").text = args.version
    ET.SubElement(item, f"{{{SPARKLE_NS}}}minimumSystemVersion").text = args.min_system
    ET.SubElement(item, "pubDate").text = format_datetime(datetime.now(timezone.utc))
    if args.release_notes_link:
        ET.SubElement(item, f"{{{SPARKLE_NS}}}releaseNotesLink").text = args.release_notes_link
    ET.SubElement(item, "enclosure", {
        "url": args.url,
        "length": str(args.length),
        "type": "application/octet-stream",
        f"{{{SPARKLE_NS}}}edSignature": args.signature,
    })

    # Newest first is what Sparkle expects to read.
    channel.insert(1, item)

    ET.indent(tree, space="  ")
    tree.write(args.appcast, encoding="utf-8", xml_declaration=True)
    print(f"appcast now lists {len(channel.findall('item'))} release(s); newest {args.version}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
