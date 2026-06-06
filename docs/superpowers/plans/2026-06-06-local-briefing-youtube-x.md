# 로컬 통합 브리핑 v2 (YouTube + X 섹션) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 기존 Claude Ecosystem Briefing을 로컬 실행으로 전환하고 YouTube(유명 LLM 인물 신규 영상)·X(주목 게시글) 섹션을 추가해 하루 2회(09:00/15:00 KST) 단일 Slack 브리핑으로 발송한다.

**Architecture:** 독립 collector 모듈(YouTube=공개 RSS, X=로그인 쿠키+내부 GraphQL)이 표준 TSV 항목 라인을 stdout으로 emit → bash 오케스트레이터(`local-briefing.sh`)가 기존 무인증 4소스와 병합·dedup·Haiku 요약·Slack 발송. macOS launchd가 9/15시 스케줄. 순수 파싱 로직은 fixture 기반 pytest로 검증, 네트워크/통합부는 DRY_RUN+수동 검증.

**Tech Stack:** bash, Python 3.14 (stdlib + `requests`), pytest 9, jq, curl, Claude Haiku API, Slack webhook, macOS launchd.

---

## 사전 조건 (검증됨)
- `python3`(3.14.5), `pip3`, `yt-dlp`, `pytest`(9.0.3), `requests`(2.33.0) 모두 설치됨 → 추가 설치 불필요.
- `.env`, `.env.*`는 이미 `.gitignore`에 포함.
- 작업 경로 기준: `/Users/picpal/Desktop/workspace/claude-code-hub` (이하 `<REPO>`).

## File Structure (생성/수정 맵)

| 파일 | 책임 |
|---|---|
| `tests/conftest.py` (생성) | `scripts/`를 import 경로에 추가 |
| `scripts/briefing_lib.py` (생성) | 공통 헬퍼: 텍스트 정제, TSV 라인, 시간 윈도우 |
| `scripts/x_parse.py` (생성) | X GraphQL 응답 파싱(순수 함수) |
| `scripts/x_endpoints.json` (생성, spike 산출) | X 엔드포인트 query_id/features |
| `scripts/collect_x.py` (생성) | X 수집기: 쿠키 인증 + GraphQL 호출 + 필터 + emit |
| `scripts/collect_youtube.py` (생성) | YouTube 수집기: RSS 파싱 + 필터 + emit |
| `scripts/resolve_channel_ids.py` (생성) | 1회 헬퍼: @handle → UC 채널 id |
| `config/creators.tsv` (생성) | 추적 인물 리스트(이름/채널id/X핸들) |
| `scripts/local-briefing.sh` (생성) | 오케스트레이터(기존 로직 이관 + 신규 collector 통합) |
| `tests/fixtures/youtube_feed.xml` (생성) | YouTube RSS 파싱 fixture |
| `tests/fixtures/x_usertweets.json` (생성) | X 응답 파싱 fixture |
| `tests/test_briefing_lib.py` / `test_x_parse.py` / `test_collect_youtube.py` (생성) | 단위 테스트 |
| `~/Library/LaunchAgents/com.claudehub.briefing.plist` (생성) | 스케줄러 |
| `.env.example` (생성) / `.gitignore` (수정) | 로컬 시크릿 템플릿 + 무시 규칙 |
| `.github/workflows/claude-briefing.yml` (수정) | cron 비활성화 |
| `.github/workflows/sync-patch-notes.yml` (수정) | briefing 트리거 스텝 제거 |

---

## Task 1: 테스트 스캐폴드 + 공통 라이브러리

**Files:**
- Create: `tests/conftest.py`
- Create: `scripts/briefing_lib.py`
- Test: `tests/test_briefing_lib.py`

- [ ] **Step 1: conftest로 import 경로 설정**

`tests/conftest.py`:
```python
import sys
import pathlib

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent.parent / "scripts"))
```

- [ ] **Step 2: 실패하는 테스트 작성**

`tests/test_briefing_lib.py`:
```python
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


def test_within_last_hours_boundaries():
    now = datetime(2026, 6, 6, 12, 0, tzinfo=timezone.utc)
    inside = datetime(2026, 6, 6, 1, 0, tzinfo=timezone.utc)
    outside = datetime(2026, 6, 4, 12, 0, tzinfo=timezone.utc)
    future = datetime(2026, 6, 7, 0, 0, tzinfo=timezone.utc)
    assert bl.within_last_hours(inside, 24, now=now) is True
    assert bl.within_last_hours(outside, 24, now=now) is False
    assert bl.within_last_hours(future, 24, now=now) is False
```

- [ ] **Step 3: 테스트 실패 확인**

Run: `cd <REPO> && python3 -m pytest tests/test_briefing_lib.py -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'briefing_lib'`

- [ ] **Step 4: 구현**

`scripts/briefing_lib.py`:
```python
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
    """Render one item as a tab-separated line with no embedded tabs."""
    fields = [
        clean_text(category, 32),
        clean_text(source, 120),
        clean_text(title, 200),
        url.strip(),
        clean_text(meta, 500),
    ]
    return "\t".join(f.replace("\t", " ") for f in fields)


def within_last_hours(dt: datetime, hours: int, now: datetime | None = None) -> bool:
    """True if dt is within the last `hours` and not in the future (tz-aware UTC)."""
    now = now or datetime.now(timezone.utc)
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return timedelta(0) <= (now - dt) <= timedelta(hours=hours)
```

- [ ] **Step 5: 테스트 통과 확인**

Run: `python3 -m pytest tests/test_briefing_lib.py -v`
Expected: PASS (3 passed)

- [ ] **Step 6: 커밋**

```bash
cd <REPO>
git add tests/conftest.py tests/test_briefing_lib.py scripts/briefing_lib.py
git commit -m "feat(briefing): 공통 라이브러리 + 테스트 스캐폴드"
```

---

## Task 2: X 내부 API spike (조사·검증)

> 비공개 GraphQL이라 endpoint/query_id/features는 실제 로그인 세션 트래픽에서 캡처해야 한다. 이 task의 산출물은 (1) `scripts/x_endpoints.json` 실값, (2) 실제 응답 fixture다. 막히면 §Task 4의 B안 폴백으로 전환.

**Files:**
- Create: `scripts/x_endpoints.json`
- Create: `tests/fixtures/x_usertweets.json`

- [ ] **Step 1: 쿠키 파일 준비**

로그인된 X 브라우저에서 DevTools → Application → Cookies → `https://x.com` → `auth_token`, `ct0` 값 복사:
```bash
mkdir -p ~/.briefing && chmod 700 ~/.briefing
cat > ~/.briefing/x_cookies.txt <<'EOF'
auth_token=PASTE_AUTH_TOKEN_VALUE
ct0=PASTE_CT0_VALUE
EOF
chmod 600 ~/.briefing/x_cookies.txt
```

- [ ] **Step 2: 실제 요청 캡처**

로그인된 X 웹에서 아무 사용자 프로필을 연다 → DevTools → Network → `graphql` 필터 → `UserByScreenName`, `UserTweets` 요청을 각각 "Copy as cURL"로 복사. 각 URL 경로 `…/graphql/<QUERY_ID>/<OpName>`에서 `<QUERY_ID>`와, 쿼리스트링의 `features` JSON을 추출한다.

- [ ] **Step 3: `x_endpoints.json` 작성 (캡처값으로 채움)**

`scripts/x_endpoints.json` — 아래 구조에 **Step 2에서 캡처한 실제 `query_id`와 `features` 객체**를 넣는다(`features`는 X가 요구하므로 캡처한 값을 그대로 복사):
```json
{
  "UserByScreenName": {
    "query_id": "PASTE_QUERY_ID",
    "op_name": "UserByScreenName",
    "features": { "PASTE": "captured features object" }
  },
  "UserTweets": {
    "query_id": "PASTE_QUERY_ID",
    "op_name": "UserTweets",
    "features": { "PASTE": "captured features object" }
  }
}
```

- [ ] **Step 4: 응답 1건을 fixture로 저장 후 구조 축약**

캡처한 `UserTweets` 응답에서 원본 트윗 1건·리플 1건만 남겨 아래 형태로 축약 저장한다. (실 응답 키 경로가 다르면 이 fixture와 §Task 3 파서를 함께 맞춘다.)

`tests/fixtures/x_usertweets.json`:
```json
{
  "data": {
    "user": {
      "result": {
        "rest_id": "111",
        "timeline_v2": {
          "timeline": {
            "instructions": [
              {
                "type": "TimelineAddEntries",
                "entries": [
                  {
                    "entryId": "tweet-1001",
                    "content": {
                      "entryType": "TimelineTimelineItem",
                      "itemContent": {
                        "tweet_results": {
                          "result": {
                            "__typename": "Tweet",
                            "rest_id": "1001",
                            "core": { "user_results": { "result": { "legacy": { "screen_name": "karpathy" } } } },
                            "legacy": {
                              "full_text": "Thoughts on scaling laws and LLMs.",
                              "created_at": "Sat Jun 06 08:00:00 +0000 2026"
                            }
                          }
                        }
                      }
                    }
                  },
                  {
                    "entryId": "tweet-1002",
                    "content": {
                      "entryType": "TimelineTimelineItem",
                      "itemContent": {
                        "tweet_results": {
                          "result": {
                            "__typename": "Tweet",
                            "rest_id": "1002",
                            "core": { "user_results": { "result": { "legacy": { "screen_name": "karpathy" } } } },
                            "legacy": {
                              "full_text": "@someone a reply tweet",
                              "created_at": "Sat Jun 06 09:00:00 +0000 2026",
                              "in_reply_to_status_id_str": "999"
                            }
                          }
                        }
                      }
                    }
                  }
                ]
              }
            ]
          }
        }
      }
    }
  }
}
```

- [ ] **Step 5: 커밋**

```bash
cd <REPO>
git add scripts/x_endpoints.json tests/fixtures/x_usertweets.json
git commit -m "chore(x): spike — 캡처한 엔드포인트/응답 fixture"
```

> 주의: `x_endpoints.json`은 비밀이 아님(쿼리 id/features). 쿠키 파일은 레포 밖(`~/.briefing/`)에 있어 커밋되지 않는다.

---

## Task 3: X 응답 파서 (TDD)

**Files:**
- Create: `scripts/x_parse.py`
- Test: `tests/test_x_parse.py`

- [ ] **Step 1: 실패하는 테스트 작성**

`tests/test_x_parse.py`:
```python
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
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `python3 -m pytest tests/test_x_parse.py -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'x_parse'`

- [ ] **Step 3: 구현**

`scripts/x_parse.py`:
```python
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
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `python3 -m pytest tests/test_x_parse.py -v`
Expected: PASS (3 passed)

- [ ] **Step 5: 커밋**

```bash
cd <REPO>
git add scripts/x_parse.py tests/test_x_parse.py
git commit -m "feat(x): GraphQL 응답 파서 + 테스트"
```

---

## Task 4: X 수집기 (쿠키 인증 + 호출 + 필터 + emit)

**Files:**
- Create: `scripts/collect_x.py`
- Test: `tests/test_collect_x.py` (read_creators 단위 테스트)

- [ ] **Step 1: read_creators 실패 테스트 작성**

`tests/test_collect_x.py`:
```python
def test_read_creators_picks_x_handle_column(tmp_path, monkeypatch):
    import collect_x

    f = tmp_path / "creators.tsv"
    f.write_text(
        "# name\tyoutube_channel_id\tx_handle\n"
        "Andrej Karpathy\tUC1\tkarpathy\n"
        "No X Person\tUC2\t\n"
        "X Only\t\tsimonw\n"
    )
    monkeypatch.setattr(collect_x, "CREATORS", f)
    assert collect_x.read_creators() == [("Andrej Karpathy", "karpathy"), ("X Only", "simonw")]
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `python3 -m pytest tests/test_collect_x.py -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'collect_x'`

- [ ] **Step 3: 구현**

`scripts/collect_x.py`:
```python
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
```

- [ ] **Step 4: read_creators 테스트 통과 확인**

Run: `python3 -m pytest tests/test_collect_x.py -v`
Expected: PASS (1 passed)

- [ ] **Step 5: 실제 X 호출 통합 검증 (수동, spike 기반)**

`config/creators.tsv`가 아직 없으면 임시로 한 줄 생성 후 실행:
```bash
cd <REPO>
printf 'Simon Willison\t\tsimonw\n' > /tmp/creators.tsv
BRIEFING_WINDOW_HOURS=720 CREATORS=/tmp/creators.tsv python3 - <<'PY'
import os, collect_x, pathlib
collect_x.CREATORS = pathlib.Path("/tmp/creators.tsv")
raise SystemExit(collect_x.main())
PY
```
Expected: stdout에 `x\t@simonw\t<텍스트>\thttps://x.com/...` 형태 라인 1개 이상.
실패(401/403/빈 출력) 시 → §B안 폴백 검토(아래). 통과 시 다음 스텝.

- [ ] **Step 6: 커밋**

```bash
cd <REPO>
git add scripts/collect_x.py tests/test_collect_x.py
git commit -m "feat(x): 쿠키 인증 수집기 + read_creators 테스트"
```

> **B안 폴백(내부 API 실패 시)**: `collect_x.py`의 `get_tweets`만 gstack `browse`로 교체한다 — 쿠키를 headless 세션에 주입 후 `https://x.com/<handle>` 이동, `article[data-testid="tweet"]` 노드에서 `div[data-testid="tweetText"]`(본문)과 `time[datetime]`(시각), 앵커 href(permalink)를 추출해 `parse_tweets`와 동일한 dict 리스트를 반환. 출력 계약·필터는 그대로 재사용. (이 폴백은 spike 실패가 확정될 때만 별도 task로 분기.)

---

## Task 5: YouTube 수집기 (RSS 파싱 TDD + main)

**Files:**
- Create: `scripts/collect_youtube.py`
- Create: `tests/fixtures/youtube_feed.xml`
- Test: `tests/test_collect_youtube.py`

- [ ] **Step 1: fixture 작성**

`tests/fixtures/youtube_feed.xml`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<feed xmlns:yt="http://www.youtube.com/xml/schemas/2015"
      xmlns:media="http://search.yahoo.com/mrss/"
      xmlns="http://www.w3.org/2005/Atom">
  <title>Test Channel</title>
  <entry>
    <id>yt:video:ABC123</id>
    <yt:videoId>ABC123</yt:videoId>
    <yt:channelId>UCxxxx</yt:channelId>
    <title>New LLM Video</title>
    <link rel="alternate" href="https://www.youtube.com/watch?v=ABC123"/>
    <published>2026-06-06T08:00:00+00:00</published>
    <media:group>
      <media:description>A deep dive into LLMs.</media:description>
    </media:group>
  </entry>
</feed>
```

- [ ] **Step 2: 실패하는 테스트 작성**

`tests/test_collect_youtube.py`:
```python
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
```

- [ ] **Step 3: 테스트 실패 확인**

Run: `python3 -m pytest tests/test_collect_youtube.py -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'collect_youtube'`

- [ ] **Step 4: 구현**

`scripts/collect_youtube.py`:
```python
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
```

- [ ] **Step 5: 테스트 통과 확인**

Run: `python3 -m pytest tests/test_collect_youtube.py -v`
Expected: PASS (3 passed)

- [ ] **Step 6: 커밋**

```bash
cd <REPO>
git add scripts/collect_youtube.py tests/test_collect_youtube.py tests/fixtures/youtube_feed.xml
git commit -m "feat(youtube): RSS 수집기 + 파싱 테스트"
```

---

## Task 6: 채널 id 해석 헬퍼 + creators.tsv 시드

**Files:**
- Create: `scripts/resolve_channel_ids.py`
- Create: `config/creators.tsv`

- [ ] **Step 1: 헬퍼 구현**

`scripts/resolve_channel_ids.py`:
```python
#!/usr/bin/env python3
"""One-time helper: resolve @handle -> UC channel id by scraping the channel page.

Usage: python3 scripts/resolve_channel_ids.py karpathy ykilcher ...
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
```

- [ ] **Step 2: 채널 id 일괄 해석**

Run:
```bash
cd <REPO>
python3 scripts/resolve_channel_ids.py AndrejKarpathy YannicKilcher TwoMinutePapers AIExplained-official mreflow DeepLearningAI 3blue1brown
```
출력의 `핸들<TAB>UC...` 값을 다음 스텝 `creators.tsv`의 채널 id 칸에 채운다. (핸들이 다르거나 NOT_FOUND면 해당 인물의 실제 YouTube 핸들을 확인해 재실행.)

- [ ] **Step 3: `config/creators.tsv` 시드 작성**

아래 스타터에 Step 2에서 얻은 `UC...` 값을 채운다. 채널 없는 인물은 채널 칸을 비운다(탭은 유지).

`config/creators.tsv`:
```
# name<TAB>youtube_channel_id<TAB>x_handle  (없는 칸은 비움)
Andrej Karpathy	UC_FILL	karpathy
Yannic Kilcher	UC_FILL	ykilcher
Two Minute Papers	UC_FILL	twominutepapers
AI Explained	UC_FILL	AIExplainedYT
Matt Wolfe	UC_FILL	mreflow
Andrew Ng	UC_FILL	AndrewYNg
3Blue1Brown	UC_FILL	3blue1brown
Jim Fan		DrJimFan
swyx		swyx
Simon Willison		simonw
Sam Altman		sama
Greg Brockman		gdb
Demis Hassabis		demishassabis
```

- [ ] **Step 4: 수집기 동작 확인 (실데이터, 넓은 윈도우)**

Run:
```bash
cd <REPO>
BRIEFING_WINDOW_HOURS=2160 python3 scripts/collect_youtube.py
```
Expected: 일부 인물의 최근 영상이 `youtube\t<채널명>\t<제목>\t<url>\t<설명>` 형태로 출력.

- [ ] **Step 5: 커밋**

```bash
cd <REPO>
git add scripts/resolve_channel_ids.py config/creators.tsv
git commit -m "feat(config): creators.tsv 시드 + 채널 id 해석 헬퍼"
```

---

## Task 7: 오케스트레이터 `local-briefing.sh`

**Files:**
- Create: `scripts/local-briefing.sh`

- [ ] **Step 1: 오케스트레이터 작성 (전체 파일)**

`scripts/local-briefing.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Load local secrets (.env: ANTHROPIC_API_KEY, SLACK_WEBHOOK_URL [, GITHUB_TOKEN])
if [ -f "$REPO_DIR/.env" ]; then set -a; . "$REPO_DIR/.env"; set +a; fi

STATE_DIR="$REPO_DIR/.briefing-state"
SEEN_FILE="${STATE_DIR}/seen-urls.txt"
mkdir -p "$STATE_DIR"; touch "$SEEN_FILE"

NEW_ITEMS_FILE=$(mktemp)
trap 'rm -f "$NEW_ITEMS_FILE"' EXIT
NEW_COUNT=0

is_seen() { grep -qxF "$1" "$SEEN_FILE" 2>/dev/null; }
mark_seen() { echo "$1" >> "$SEEN_FILE"; }

add_item() {
  local category="$1" source="$2" title="$3" url="$4" summary="${5:-}"
  printf '[%s][%s] %s\n  URL: %s\n  %s\n\n' "$category" "$source" "$title" "$url" "$summary" >> "$NEW_ITEMS_FILE"
  mark_seen "$url"
  NEW_COUNT=$((NEW_COUNT + 1))
  echo "  NEW: [$category][$source] $title"
}

ingest_tsv() {
  while IFS=$'\t' read -r category source title url meta; do
    [ -z "${url:-}" ] && continue
    is_seen "$url" && continue
    add_item "$category" "$source" "$title" "$url" "$meta"
  done
}

# ---- Source 1: Anthropic Blog ----
echo "=== Anthropic blog ==="
BLOG_HTML=$(curl -sfL --connect-timeout 10 -m 30 -H "User-Agent: Mozilla/5.0 (compatible; ClaudeCodeHub/1.0)" "https://www.anthropic.com/news" 2>/dev/null || echo "")
if [ -n "$BLOG_HTML" ]; then
  while IFS= read -r path; do
    [ -z "$path" ] && continue
    FULL_URL="https://www.anthropic.com${path}"
    is_seen "$FULL_URL" || add_item "news" "Anthropic Blog" "$(echo "$path" | sed 's|.*/||; s/-/ /g')" "$FULL_URL" ""
  done < <(echo "$BLOG_HTML" | grep -oP 'href="\K/news/[^"]+' | sort -u | head -15)
fi

# ---- Source 2: Claude Blog ----
echo "=== Claude blog ==="
CLAUDE_BLOG_HTML=$(curl -sfL --connect-timeout 10 -m 30 -H "User-Agent: Mozilla/5.0 (compatible; ClaudeCodeHub/1.0)" "https://claude.com/blog" 2>/dev/null || echo "")
if [ -n "$CLAUDE_BLOG_HTML" ]; then
  while IFS= read -r path; do
    [ -z "$path" ] && continue
    FULL_URL="https://claude.com${path}"
    is_seen "$FULL_URL" || add_item "news" "Claude Blog" "$(echo "$path" | sed 's|.*/||; s/-/ /g')" "$FULL_URL" ""
  done < <(echo "$CLAUDE_BLOG_HTML" | grep -oP 'href="\K/blog/[^"]+' | sort -u | head -15)
fi

# ---- Source 3: Hacker News ----
echo "=== Hacker News ==="
TWENTY_FOUR_H_AGO=$(($(date +%s) - 86400))
HN_RESULT=$(curl -sf --connect-timeout 10 -m 30 "https://hn.algolia.com/api/v1/search_by_date?query=claude+anthropic&tags=story&numericFilters=created_at_i>${TWENTY_FOUR_H_AGO}&hitsPerPage=15" 2>/dev/null || echo '{"hits":[]}')
while read -r story; do
  [ -z "$story" ] || [ "$story" = "null" ] && continue
  TITLE=$(echo "$story" | jq -r '.title // ""')
  URL=$(echo "$story" | jq -r '.url // ""')
  OBJ_ID=$(echo "$story" | jq -r '.objectID')
  HN_URL="https://news.ycombinator.com/item?id=${OBJ_ID}"
  [ -z "$URL" ] && URL="$HN_URL"
  POINTS=$(echo "$story" | jq -r '.points // 0')
  COMMENTS=$(echo "$story" | jq -r '.num_comments // 0')
  if [ -n "$TITLE" ] && ! is_seen "$URL"; then
    add_item "community" "HN (${POINTS}pts, ${COMMENTS}c)" "$TITLE" "$URL" "Discussion: $HN_URL"
  fi
done < <(echo "$HN_RESULT" | jq -c '.hits[]' 2>/dev/null || true)

# ---- Source 4: GitHub Releases ----
echo "=== GitHub releases ==="
RELEASES=$(curl -sf --connect-timeout 10 -m 30 -H "Accept: application/vnd.github+json" ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} "https://api.github.com/repos/anthropics/claude-code/releases?per_page=5" 2>/dev/null || echo "[]")
while read -r release; do
  [ -z "$release" ] || [ "$release" = "null" ] && continue
  TAG=$(echo "$release" | jq -r '.tag_name')
  URL=$(echo "$release" | jq -r '.html_url')
  DATE=$(echo "$release" | jq -r '.published_at' | cut -dT -f1)
  BODY_LINES=$(echo "$release" | jq -r '.body // ""' | head -3 | tr '\n' ' ')
  if ! is_seen "release:${TAG}"; then
    add_item "tech" "Release" "${TAG} (${DATE})" "$URL" "$BODY_LINES"
    mark_seen "release:${TAG}"
  fi
done < <(echo "$RELEASES" | jq -c '.[]' 2>/dev/null || true)

# ---- Source 5: YouTube ----
echo "=== YouTube ==="
ingest_tsv < <(python3 "$SCRIPT_DIR/collect_youtube.py" 2>>"$STATE_DIR/collect.log")

# ---- Source 6: X ----
echo "=== X ==="
ingest_tsv < <(python3 "$SCRIPT_DIR/collect_x.py" 2>>"$STATE_DIR/collect.log")

# ---- First-run seed ----
if [ ! -f "${STATE_DIR}/.seeded" ]; then
  echo "=== First run: seeding (${NEW_COUNT} items), no send ==="
  touch "${STATE_DIR}/.seeded"; exit 0
fi

echo "=== Total new items: $NEW_COUNT ==="
[ "$NEW_COUNT" -eq 0 ] && { echo "No new items."; exit 0; }

# ---- Generate briefing via Claude API ----
RAW_ITEMS=$(cat "$NEW_ITEMS_FILE")
SYSTEM_PROMPT='You are a Claude/LLM ecosystem analyst writing a Slack briefing in Korean (한국어).

Each input item is tagged [category][source]. Categories map to fixed sections:
- news/tech/community → 핵심/기술/커뮤니티 판단
- youtube → 🎥 YouTube 섹션
- x → 🐦 X 섹션

Format (Slack mrkdwn), omit any empty section:
*📰 오늘의 핵심* — 가장 중요한 1~3건. 제목 + 한 줄 요약 + <url|출처>
*🔧 기술 업데이트* — category=tech (릴리스/API 변경)
*🌐 커뮤니티 동향* — category=community (HN 등)
*🎥 YouTube — 유명 인물 신규 영상* — category=youtube. 각 항목: • 제목 — 한 줄 핵심 <url|채널명>
*🐦 X — 주목 게시글* — category=x. 각 항목: • 한 줄 핵심 <url|@핸들>
*💡 인사이트* — 관통하는 트렌드 1~2문장.

Rules:
- 한국어. 기술 용어만 영어 유지.
- Slack mrkdwn: *bold*, <url|title>, \n newlines.
- 간결하게 (350단어 이내).
- YouTube/X 항목은 반드시 핵심 한 줄 + 출처 링크를 함께.
- 끝에 "📊 새 소식 N건" 한 줄 추가.'

BRIEFING_RESPONSE=$(curl -s --connect-timeout 10 -m 120 -X POST "https://api.anthropic.com/v1/messages" \
  -H "x-api-key: ${ANTHROPIC_API_KEY}" -H "anthropic-version: 2023-06-01" -H "content-type: application/json" \
  -d "$(jq -n --arg system "$SYSTEM_PROMPT" --arg items "$RAW_ITEMS" \
    '{model:"claude-haiku-4-5-20251001",max_tokens:2048,system:$system,messages:[{role:"user",content:("다음 항목들로 브리핑을 작성해줘:\n\n"+$items)}]}')" 2>&1) || true

if echo "$BRIEFING_RESPONSE" | jq -e '.content[0].text' >/dev/null 2>&1; then
  BRIEFING=$(echo "$BRIEFING_RESPONSE" | jq -r '.content[0].text')
else
  echo "  Claude API failed: $(echo "$BRIEFING_RESPONSE" | head -c 200)"
  BRIEFING="⚠️ AI 요약 생성 실패\n\n원본:\n${RAW_ITEMS}"
fi

# ---- Send to Slack ----
BRIEF_TIME=$(date "+%H:%M")
if [ -n "${SLACK_WEBHOOK_URL:-}" ] && [ "${DRY_RUN:-0}" != "1" ]; then
  SLACK_TEXT="🤖 *Claude Ecosystem Briefing* (${BRIEF_TIME})\n\n${BRIEFING}\n\n🔗 *사이트:* <https://picpal.github.io/claude-code-hub|Claude Code Hub>"
  curl -sf -X POST "$SLACK_WEBHOOK_URL" -H 'Content-type: application/json' -d "$(jq -n --arg text "$SLACK_TEXT" '{text:$text}')" \
    && echo "  Slack sent" || echo "  Slack failed"
else
  echo "--- DRY RUN / no webhook ---"; echo -e "$BRIEFING"; echo "---"
fi

# ---- Trim state ----
if [ "$(wc -l < "$SEEN_FILE" | tr -d ' ')" -gt 1000 ]; then
  tail -800 "$SEEN_FILE" > "${SEEN_FILE}.tmp" && mv "${SEEN_FILE}.tmp" "$SEEN_FILE"
fi
echo "=== Briefing complete ==="
```

- [ ] **Step 2: 실행 권한 + 문법 점검**

Run:
```bash
cd <REPO>
chmod +x scripts/local-briefing.sh
bash -n scripts/local-briefing.sh && echo "syntax ok"
```
Expected: `syntax ok`

- [ ] **Step 3: DRY_RUN 엔드투엔드 (seed 동작 확인)**

> 현재 `.briefing-state/.seeded`가 이미 존재(기존 클라우드 실행 이력). 신규 항목만 잡혀야 정상.

Run:
```bash
cd <REPO>
DRY_RUN=1 bash scripts/local-briefing.sh
```
Expected: 각 소스 수집 로그 출력 → 신규 0건이면 "No new items.", 신규가 있으면 `--- DRY RUN ---` 아래 한국어 브리핑(🎥/🐦 섹션 포함 가능)이 stdout에 표시. Slack 미발송.

- [ ] **Step 4: 전체 테스트 재실행 (회귀 확인)**

Run: `python3 -m pytest tests/ -v`
Expected: 전체 PASS

- [ ] **Step 5: 커밋**

```bash
cd <REPO>
git add scripts/local-briefing.sh
git commit -m "feat(briefing): 로컬 오케스트레이터 (4소스 + YouTube + X 통합)"
```

---

## Task 8: 스케줄러 + 로컬 시크릿 + 클라우드 비활성화

**Files:**
- Create: `~/Library/LaunchAgents/com.claudehub.briefing.plist`
- Create: `.env.example`
- Modify: `.gitignore`
- Modify: `.github/workflows/claude-briefing.yml`
- Modify: `.github/workflows/sync-patch-notes.yml`

- [ ] **Step 1: `.env` + `.env.example` 준비**

`.env.example` (생성):
```
ANTHROPIC_API_KEY=sk-ant-xxxx
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/xxx/yyy/zzz
# optional: GitHub API rate limit 완화용 (없어도 동작)
GITHUB_TOKEN=
```
실제 `.env` 생성(값은 사용자 보유분 입력):
```bash
cd <REPO>
cp .env.example .env
# 편집기로 .env에 실제 키 입력
```
(`.env`는 이미 gitignore됨.)

- [ ] **Step 2: `.gitignore`에 로그/캐시 추가**

`.gitignore`의 `# Logs` 섹션을 아래로 교체:
```
# Logs
*.log
.briefing-state/*.log

# Python
__pycache__/
.pytest_cache/
```

- [ ] **Step 3: launchd plist 작성**

`~/Library/LaunchAgents/com.claudehub.briefing.plist`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>com.claudehub.briefing</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>/Users/picpal/Desktop/workspace/claude-code-hub/scripts/local-briefing.sh</string>
  </array>
  <key>WorkingDirectory</key>
  <string>/Users/picpal/Desktop/workspace/claude-code-hub</string>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key><string>/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
  </dict>
  <key>StartCalendarInterval</key>
  <array>
    <dict><key>Hour</key><integer>9</integer><key>Minute</key><integer>0</integer></dict>
    <dict><key>Hour</key><integer>15</integer><key>Minute</key><integer>0</integer></dict>
  </array>
  <key>StandardOutPath</key>
  <string>/Users/picpal/Desktop/workspace/claude-code-hub/.briefing-state/launchd.out.log</string>
  <key>StandardErrorPath</key>
  <string>/Users/picpal/Desktop/workspace/claude-code-hub/.briefing-state/launchd.err.log</string>
</dict>
</plist>
```

- [ ] **Step 4: launchd 등록 + 즉시 1회 실행 검증**

Run:
```bash
launchctl unload ~/Library/LaunchAgents/com.claudehub.briefing.plist 2>/dev/null || true
launchctl load -w ~/Library/LaunchAgents/com.claudehub.briefing.plist
launchctl list | grep claudehub
launchctl start com.claudehub.briefing
sleep 5 && tail -n 20 <REPO>/.briefing-state/launchd.out.log
```
Expected: `launchctl list`에 라벨 표시, 로그에 수집 단계 출력. (Slack 발송은 신규 항목 있을 때만.)

- [ ] **Step 5: 클라우드 cron 비활성화 — `claude-briefing.yml`**

`.github/workflows/claude-briefing.yml`의 `on:` 블록을 아래로 교체(스케줄 제거, 수동 트리거만 유지):
```yaml
on:
  workflow_dispatch:
```

- [ ] **Step 6: `sync-patch-notes.yml`의 briefing 트리거 제거**

`.github/workflows/sync-patch-notes.yml`에서 아래 스텝 블록 전체를 삭제:
```yaml
      - name: Trigger briefing
        if: steps.push_check.outputs.pushed == 'true'
        run: gh workflow run claude-briefing.yml
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

- [ ] **Step 7: 커밋**

```bash
cd <REPO>
git add .env.example .gitignore .github/workflows/claude-briefing.yml .github/workflows/sync-patch-notes.yml
git commit -m "chore(briefing): 로컬 스케줄러 전환 — 클라우드 cron 비활성화 + .env 템플릿"
```

> plist는 홈 디렉토리(레포 밖)라 커밋 대상 아님. 백업이 필요하면 `scripts/com.claudehub.briefing.plist`로 사본을 두고 별도 커밋(경로는 사용자 환경 고정값이라 선택사항).

---

## Self-Review

**1. Spec coverage** (spec 섹션 → task 매핑)
- §4 아키텍처(collector→오케스트레이터) → Task 4/5/7 ✓
- §5.1 creators.tsv → Task 6 ✓ / §5.2 YouTube collector → Task 5 ✓ / §5.3 X collector(C안)+B폴백 → Task 4 ✓
- §5.4 오케스트레이터 → Task 7 ✓ / §5.5 launchd → Task 8 ✓ / §5.6 .env → Task 8 ✓ / §5.7 클라우드 변경 → Task 8 ✓
- §6 데이터 계약(TSV 5필드) → Task 1 `to_tsv_line` + Task 7 `ingest_tsv` ✓
- §7 Slack 고정 섹션 → Task 7 SYSTEM_PROMPT ✓ / §8 dedup/seed/trim → Task 7 ✓
- §9 에러/폴백 → 각 collector try/except + 401 break + Haiku 폴백 ✓
- §10 보안(쿠키 권한/gitignore) → Task 2 chmod 600 + Task 8 gitignore ✓
- §11 테스트(DRY_RUN, 단위, spike) → Task 1/3/4/5 + Task 2 spike + Task 7 DRY_RUN ✓
- §14 오픈이슈(엔드포인트/쿠키 절차) → Task 2 spike에서 확정 ✓

**2. Placeholder scan**: 코드 스텝은 모두 완전한 코드 포함. `UC_FILL`/`PASTE_*`는 Task 2/6에서 "캡처/해석값을 채운다"는 정의된 액션의 산출 슬롯이며, 해당 스텝에 채우는 방법(명령/출처)을 구체적으로 명시함 → 모호 placeholder 아님.

**3. Type consistency**: collector dict 키(`id/screen_name/text/created_at/url`, `video_id/title/published/description/url`)가 정의 task와 사용처 일치. `to_tsv_line(category,source,title,url,meta)` 시그니처가 양 collector·`ingest_tsv`의 5필드와 일치. `within_last_hours(dt,hours,now=)` 호출부 일치. `read_creators`는 X=3번째 칸/YouTube=2번째 칸으로 분리, 각 테스트로 고정.

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-06-06-local-briefing-youtube-x.md`.

**주의(중요)**: Task 2(X spike)와 Task 4 Step 5(실 X 호출), Task 6 Step 2(채널 id 해석)는 **로그인 세션·실네트워크가 필요한 수동/대화형 단계**다. 서브에이전트 자동 실행 시 이 단계들은 사용자 개입(쿠키 추출, cURL 캡처)이 필요하므로 해당 task에서 일시정지하고 사용자에게 입력을 요청해야 한다.
