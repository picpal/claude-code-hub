"""Shared helpers for briefing collectors. Stdlib only."""
from __future__ import annotations

import re
from datetime import datetime, timedelta, timezone


def clean_text(text: str, limit: int = 280) -> str:
    """Collapse all whitespace to single spaces, strip, truncate to limit."""
    if not text:
        return ""
    collapsed = re.sub(r"\s+", " ", text).strip()
    return collapsed[:limit]


def to_tsv_line(category: str, source: str, title: str, url: str, meta: str = "") -> str:
    """Render one item as a tab-separated line with no embedded tabs or newlines."""
    fields = [
        clean_text(category, 32),
        clean_text(source, 120),
        clean_text(title, 200),
        "".join(url.split()),  # URLs carry no whitespace; strip embedded \n/\t so TSV rows stay intact
        clean_text(meta, 500),
    ]
    # Guard every field against embedded tabs/newlines that would corrupt the TSV record.
    return "\t".join(f.replace("\t", " ").replace("\n", " ").replace("\r", " ") for f in fields)


def within_last_hours(dt: datetime, hours: int, now: datetime | None = None) -> bool:
    """True if dt is within the last `hours` and not in the future (tz-aware UTC)."""
    now = now or datetime.now(timezone.utc)
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return timedelta(0) <= (now - dt) <= timedelta(hours=hours)
