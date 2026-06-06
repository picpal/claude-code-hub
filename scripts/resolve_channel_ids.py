#!/usr/bin/env python3
"""One-time helper: resolve a YouTube @handle to its UC channel id.

Usage: python3 scripts/resolve_channel_ids.py karpathy YannicKilcher ...
Prints "handle<TAB>UC..." (or NOT_FOUND) for pasting into config/creators.tsv.
"""
import re
import sys

import requests


def resolve(handle: str) -> str | None:
    handle = handle.lstrip("@")
    r = requests.get(
        f"https://www.youtube.com/@{handle}",
        timeout=20,
        headers={"user-agent": "Mozilla/5.0"},
    )
    r.raise_for_status()
    m = re.search(r'"(?:channelId|externalId)":"(UC[\w-]{22})"', r.text)
    return m.group(1) if m else None


if __name__ == "__main__":
    for h in sys.argv[1:]:
        try:
            print(f"{h}\t{resolve(h) or 'NOT_FOUND'}")
        except Exception as e:  # noqa: BLE001
            print(f"{h}\tERROR: {e}")
