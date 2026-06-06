#!/usr/bin/env python3
"""Collect recent videos from creators' YouTube channels via public RSS.

Outputs TSV item lines (category=youtube) to stdout. No auth needed.
"""
from __future__ import annotations

import os
import sys
import xml.etree.ElementTree as ET
from datetime import datetime, timezone
from pathlib import Path

import requests

from briefing_lib import to_tsv_line, within_last_hours

REPO = Path(__file__).resolve().parent.parent
CREATORS = REPO / "config" / "creators.tsv"
WINDOW_HOURS = int(os.environ.get("BRIEFING_WINDOW_HOURS", "24"))
NS = {
    "atom": "http://www.w3.org/2005/Atom",
    "yt": "http://www.youtube.com/xml/schemas/2015",
    "media": "http://search.yahoo.com/mrss/",
}


def parse_feed(xml_text: str) -> list[dict]:
    """Parse a YouTube channel Atom feed into a list of video dicts."""
    root = ET.fromstring(xml_text)
    out = []
    for entry in root.findall("atom:entry", NS):
        vid_el = entry.find("yt:videoId", NS)
        title_el = entry.find("atom:title", NS)
        pub_el = entry.find("atom:published", NS)
        desc_el = entry.find("media:group/media:description", NS)
        if vid_el is None or pub_el is None:
            continue
        try:
            published = datetime.fromisoformat(pub_el.text).astimezone(timezone.utc)
        except (TypeError, ValueError):
            continue
        out.append(
            {
                "video_id": vid_el.text,
                "title": (title_el.text if title_el is not None else "") or "",
                "published": published,
                "description": (desc_el.text if desc_el is not None else "") or "",
                "url": f"https://www.youtube.com/watch?v={vid_el.text}",
            }
        )
    return out


def read_creators():
    out = []
    if not CREATORS.exists():
        return out
    for line in CREATORS.read_text().splitlines():
        if not line.strip() or line.startswith("#"):
            continue
        cols = line.split("\t")
        name = cols[0].strip() if len(cols) > 0 else ""
        channel_id = cols[1].strip() if len(cols) > 1 else ""
        if channel_id:
            out.append((name, channel_id))
    return out


def main() -> int:
    for name, channel_id in read_creators():
        url = f"https://www.youtube.com/feeds/videos.xml?channel_id={channel_id}"
        try:
            r = requests.get(url, timeout=20, headers={"user-agent": "Mozilla/5.0"})
            r.raise_for_status()
            for v in parse_feed(r.text):
                if not within_last_hours(v["published"], WINDOW_HOURS):
                    continue
                print(to_tsv_line("youtube", name, v["title"], v["url"], v["description"]))
        except Exception as e:  # noqa: BLE001 — collector must never crash the pipeline
            print(f"WARN: YT fetch {name} failed: {e}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
