import pathlib

import collect_youtube as cy

FIX = pathlib.Path(__file__).parent / "fixtures" / "youtube_feed.xml"


def test_parse_feed_extracts_fields():
    videos = cy.parse_feed(FIX.read_text())
    assert len(videos) == 1
    v = videos[0]
    assert v["video_id"] == "ABC123"
    assert v["title"] == "New LLM Video"
    assert v["url"] == "https://www.youtube.com/watch?v=ABC123"
    assert "deep dive" in v["description"].lower()
    assert v["published"].year == 2026


def test_parse_feed_empty():
    assert cy.parse_feed("<feed xmlns='http://www.w3.org/2005/Atom'></feed>") == []


def test_read_creators_picks_channel_id_column(tmp_path, monkeypatch):
    f = tmp_path / "creators.tsv"
    f.write_text("# h\nAndrej\tUC1\tkarpathy\nXonly\t\tsimonw\n")
    monkeypatch.setattr(cy, "CREATORS", f)
    assert cy.read_creators() == [("Andrej", "UC1")]
