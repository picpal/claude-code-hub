from datetime import datetime, timezone

import briefing_lib as bl


def test_clean_text_collapses_and_truncates():
    assert bl.clean_text("a\n  b\t c") == "a b c"
    assert bl.clean_text("x" * 500, limit=10) == "x" * 10
    assert bl.clean_text("") == ""


def test_to_tsv_line_has_five_fields_and_no_embedded_tabs():
    line = bl.to_tsv_line("x", "@h", "ti\ttle", "http://u", "me\nta")
    parts = line.split("\t")
    assert len(parts) == 5
    assert parts[0] == "x"
    assert parts[3] == "http://u"
    assert "\t" not in parts[2]


def test_to_tsv_line_strips_embedded_newlines():
    # An embedded newline (in any field, incl. URL) must not break the single-line TSV record.
    line = bl.to_tsv_line("x", "@h", "ti\ntle", "http://u/\npath", "a\r\nb")
    assert "\n" not in line and "\r" not in line
    assert line.count("\t") == 4  # exactly 5 fields → 4 separators
    assert line.split("\t")[3] == "http://u/path"  # URL whitespace fully removed


def test_within_last_hours_boundaries():
    now = datetime(2026, 6, 6, 12, 0, tzinfo=timezone.utc)
    inside = datetime(2026, 6, 6, 1, 0, tzinfo=timezone.utc)
    outside = datetime(2026, 6, 4, 12, 0, tzinfo=timezone.utc)
    future = datetime(2026, 6, 7, 0, 0, tzinfo=timezone.utc)
    assert bl.within_last_hours(inside, 24, now=now) is True
    assert bl.within_last_hours(outside, 24, now=now) is False
    assert bl.within_last_hours(future, 24, now=now) is False
