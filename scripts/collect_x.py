#!/usr/bin/env python3
"""Collect recent original X posts from creators in config/creators.tsv.

Outputs TSV item lines (category=x) to stdout. Auth via ~/.briefing/x_cookies.txt.
"""
from __future__ import annotations

import json
import os
import sys
import time
from pathlib import Path

import requests

from briefing_lib import clean_text, to_tsv_line, within_last_hours
from x_parse import parse_tweets, parse_user_id

REPO = Path(__file__).resolve().parent.parent
COOKIE_FILE = Path(os.path.expanduser("~/.briefing/x_cookies.txt"))
CREATORS = REPO / "config" / "creators.tsv"
WINDOW_HOURS = int(os.environ.get("BRIEFING_WINDOW_HOURS", "24"))
# Long-standing public X web client bearer (refresh if 403s persist).
WEB_BEARER = (
    "Bearer AAAAAAAAAAAAAAAAAAAAANRILgAAAAAAnNwIzUejRCOuH5E6I8xnZz4puTs"
    "%3D1Zv7ttfk8LF81IUq16cHjhLTvJu4FA33AGWWjCpTnA"
)


def load_endpoints() -> dict:
    p = Path(__file__).parent / "x_endpoints.json"
    return json.loads(p.read_text()) if p.exists() else {}


def load_cookies() -> dict:
    """Read 'name=value' lines (auth_token, ct0) from the cookie file."""
    jar = {}
    if not COOKIE_FILE.exists():
        return jar
    for line in COOKIE_FILE.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        jar[k.strip()] = v.strip()
    return jar


def make_session(cookies: dict) -> requests.Session:
    s = requests.Session()
    s.headers.update(
        {
            "authorization": WEB_BEARER,
            "x-csrf-token": cookies.get("ct0", ""),
            "x-twitter-active-user": "yes",
            "x-twitter-auth-type": "OAuth2Session",
            "content-type": "application/json",
            "user-agent": "Mozilla/5.0",
        }
    )
    s.cookies.update(
        {"auth_token": cookies.get("auth_token", ""), "ct0": cookies.get("ct0", "")}
    )
    return s


def _gql(session: requests.Session, ep: dict, variables: dict) -> dict:
    params = {"variables": json.dumps(variables), "features": json.dumps(ep.get("features", {}))}
    url = f"https://x.com/i/api/graphql/{ep['query_id']}/{ep['op_name']}"
    r = session.get(url, params=params, timeout=20)
    r.raise_for_status()
    return r.json()


def get_user_id(session, endpoints, handle):
    return parse_user_id(_gql(session, endpoints["UserByScreenName"], {"screen_name": handle}))


def get_tweets(session, endpoints, user_id):
    variables = {
        "userId": user_id,
        "count": 20,
        "includePromotedContent": False,
        "withQuickPromoteEligibilityTweetFields": False,
        "withVoice": False,
    }
    return parse_tweets(_gql(session, endpoints["UserTweets"], variables))


def read_creators():
    out = []
    if not CREATORS.exists():
        return out
    for line in CREATORS.read_text().splitlines():
        if not line.strip() or line.startswith("#"):
            continue
        cols = line.split("\t")
        name = cols[0].strip() if len(cols) > 0 else ""
        x_handle = cols[2].strip() if len(cols) > 2 else ""
        if x_handle:
            out.append((name, x_handle))
    return out


def main() -> int:
    cookies = load_cookies()
    if not cookies.get("auth_token") or not cookies.get("ct0"):
        print(
            "WARN: X cookies missing/expired — re-export to ~/.briefing/x_cookies.txt",
            file=sys.stderr,
        )
        return 0
    endpoints = load_endpoints()
    if not endpoints:
        print("WARN: scripts/x_endpoints.json missing — run Task 2 spike", file=sys.stderr)
        return 0
    session = make_session(cookies)
    for name, handle in read_creators():
        try:
            uid = get_user_id(session, endpoints, handle)
            if not uid:
                print(f"WARN: could not resolve @{handle}", file=sys.stderr)
                continue
            for tw in get_tweets(session, endpoints, uid):
                if not within_last_hours(tw["created_at"], WINDOW_HOURS):
                    continue
                print(to_tsv_line("x", f"@{handle}", clean_text(tw["text"], 120), tw["url"], tw["text"]))
            time.sleep(1)
        except requests.HTTPError as e:
            code = e.response.status_code if e.response is not None else "?"
            print(f"WARN: X fetch @{handle} failed (HTTP {code})", file=sys.stderr)
            if str(code) in ("401", "403"):
                print("WARN: X auth invalid — re-export cookies", file=sys.stderr)
                break
        except Exception as e:  # noqa: BLE001 — collector must never crash the pipeline
            print(f"WARN: X fetch @{handle} error: {e}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
