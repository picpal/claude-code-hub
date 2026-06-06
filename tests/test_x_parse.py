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


def _tweet_item(rest_id, screen, text, created, *, reply=False):
    legacy = {"full_text": text, "created_at": created}
    if reply:
        legacy["in_reply_to_status_id_str"] = "999"
    return {
        "entryId": f"tweet-{rest_id}",
        "content": {
            "entryType": "TimelineTimelineItem",
            "itemContent": {
                "tweet_results": {
                    "result": {
                        "__typename": "Tweet",
                        "rest_id": rest_id,
                        # Newer X: screen_name under core (not legacy)
                        "core": {"user_results": {"result": {"core": {"screen_name": screen}}}},
                        "legacy": legacy,
                    }
                }
            },
        },
    }


def test_parse_tweets_new_timeline_and_core_screen_name():
    # Real-world shape: result.timeline (not timeline_v2), screen_name under core,
    # a leading non-AddEntries instruction, plus a module entry with items[].
    payload = {
        "data": {
            "user": {
                "result": {
                    "rest_id": "555",
                    "timeline": {
                        "timeline": {
                            "instructions": [
                                {"type": "TimelineClearCache"},
                                {
                                    "type": "TimelineAddEntries",
                                    "entries": [
                                        _tweet_item("2001", "simonw", "A real original post.", "Sat Jun 06 08:00:00 +0000 2026"),
                                        _tweet_item("2002", "simonw", "@x a reply.", "Sat Jun 06 09:00:00 +0000 2026", reply=True),
                                        {
                                            "entryId": "module-1",
                                            "content": {
                                                "entryType": "TimelineTimelineModule",
                                                "items": [
                                                    {
                                                        "item": {
                                                            "itemContent": {
                                                                "tweet_results": {
                                                                    "result": {
                                                                        "__typename": "Tweet",
                                                                        "rest_id": "2003",
                                                                        "core": {"user_results": {"result": {"core": {"screen_name": "simonw"}}}},
                                                                        "legacy": {"full_text": "Thread post.", "created_at": "Sat Jun 06 10:00:00 +0000 2026"},
                                                                    }
                                                                }
                                                            }
                                                        }
                                                    }
                                                ],
                                            },
                                        },
                                    ],
                                },
                            ]
                        }
                    },
                }
            }
        }
    }
    tweets = x_parse.parse_tweets(payload)
    ids = [t["id"] for t in tweets]
    assert ids == ["2001", "2003"]  # reply (2002) skipped; module tweet (2003) included
    assert tweets[0]["screen_name"] == "simonw"
    assert tweets[0]["url"] == "https://x.com/simonw/status/2001"
