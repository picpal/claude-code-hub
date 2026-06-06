import json
import pathlib

import x_parse

FIX = pathlib.Path(__file__).parent / "fixtures" / "x_usertweets.json"


def _load():
    return json.loads(FIX.read_text())


def test_parse_user_id():
    assert x_parse.parse_user_id(_load()) == "111"


def test_parse_tweets_returns_only_originals():
    tweets = x_parse.parse_tweets(_load())
    assert [t["id"] for t in tweets] == ["1001"]
    t = tweets[0]
    assert t["screen_name"] == "karpathy"
    assert t["url"] == "https://x.com/karpathy/status/1001"
    assert t["created_at"].year == 2026
    assert "scaling laws" in t["text"]


def test_parse_handles_garbage():
    assert x_parse.parse_user_id({}) is None
    assert x_parse.parse_tweets({}) == []
