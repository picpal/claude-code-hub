"""Parse X (Twitter) GraphQL UserByScreenName / UserTweets responses. Stdlib only."""
from __future__ import annotations

from datetime import datetime, timezone

X_TIME_FMT = "%a %b %d %H:%M:%S %z %Y"


def parse_user_id(payload: dict) -> str | None:
    try:
        return payload["data"]["user"]["result"]["rest_id"]
    except (KeyError, TypeError):
        return None


def _iter_tweet_results(payload: dict):
    try:
        instructions = (
            payload["data"]["user"]["result"]["timeline_v2"]["timeline"]["instructions"]
        )
    except (KeyError, TypeError):
        return
    for ins in instructions:
        if ins.get("type") != "TimelineAddEntries":
            continue
        for entry in ins.get("entries", []):
            content = entry.get("content", {})
            if content.get("entryType") != "TimelineTimelineItem":
                continue
            res = content.get("itemContent", {}).get("tweet_results", {}).get("result")
            if not res:
                continue
            if res.get("__typename") == "TweetWithVisibilityResults":
                res = res.get("tweet", res)
            yield res


def parse_tweets(payload: dict) -> list[dict]:
    """Return original tweets only (no retweets/replies) as dicts."""
    out = []
    for res in _iter_tweet_results(payload):
        legacy = res.get("legacy") or {}
        if legacy.get("retweeted_status_result"):
            continue
        if legacy.get("in_reply_to_status_id_str"):
            continue
        tid = res.get("rest_id") or legacy.get("id_str")
        created_raw = legacy.get("created_at")
        try:
            created = datetime.strptime(created_raw, X_TIME_FMT).astimezone(timezone.utc)
        except (TypeError, ValueError):
            continue
        try:
            screen = res["core"]["user_results"]["result"]["legacy"]["screen_name"]
        except (KeyError, TypeError):
            screen = ""
        if not tid or not screen:
            continue
        out.append(
            {
                "id": tid,
                "screen_name": screen,
                "text": legacy.get("full_text", ""),
                "created_at": created,
                "url": f"https://x.com/{screen}/status/{tid}",
            }
        )
    return out
