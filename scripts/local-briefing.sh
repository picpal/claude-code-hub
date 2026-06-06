#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Local secrets (.env: ANTHROPIC_API_KEY, SLACK_WEBHOOK_URL [, GITHUB_TOKEN])
if [ -f "$REPO_DIR/.env" ]; then set -a; . "$REPO_DIR/.env"; set +a; fi

# Python: prefer the repo venv (has requests + browser_cookie3); fall back to system.
PY="$REPO_DIR/.venv/bin/python"
[ -x "$PY" ] || PY="python3"

STATE_DIR="$REPO_DIR/.briefing-state"
SEEN_FILE="${STATE_DIR}/seen-urls.txt"
mkdir -p "$STATE_DIR"; touch "$SEEN_FILE"

NEW_ITEMS_FILE=$(mktemp)
trap 'rm -f "$NEW_ITEMS_FILE"' EXIT
NEW_COUNT=0
X_FAILED=0

is_seen() { grep -qxF "$1" "$SEEN_FILE" 2>/dev/null; }
mark_seen() { echo "$1" >> "$SEEN_FILE"; }

add_item() {
  local category="$1" source="$2" title="$3" url="$4" summary="${5:-}"
  printf '[%s][%s] %s\n  URL: %s\n  %s\n\n' "$category" "$source" "$title" "$url" "$summary" >> "$NEW_ITEMS_FILE"
  mark_seen "$url"
  NEW_COUNT=$((NEW_COUNT + 1))
  echo "  NEW: [$category][$source] $title"
}

# Ingest TSV (category<TAB>source<TAB>title<TAB>url<TAB>meta) from a collector.
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

# ---- Source 5: YouTube (public RSS, no auth) ----
echo "=== YouTube ==="
YT_OUT=$(mktemp)
"$PY" "$SCRIPT_DIR/collect_youtube.py" >"$YT_OUT" 2>>"$STATE_DIR/collect.log" || true
ingest_tsv < "$YT_OUT"; rm -f "$YT_OUT"

# ---- Source 6: X (logged-in session cookies) ----
echo "=== X ==="
X_OUT=$(mktemp)
X_RC=0
"$PY" "$SCRIPT_DIR/collect_x.py" >"$X_OUT" 2>>"$STATE_DIR/collect.log" || X_RC=$?
ingest_tsv < "$X_OUT"; rm -f "$X_OUT"
[ "$X_RC" -eq 2 ] && X_FAILED=1

# ---- First-run seed ----
if [ ! -f "${STATE_DIR}/.seeded" ]; then
  echo "=== First run: seeding (${NEW_COUNT} items), no send ==="
  touch "${STATE_DIR}/.seeded"; exit 0
fi

echo "=== Total new items: $NEW_COUNT (X_FAILED=$X_FAILED) ==="
if [ "$NEW_COUNT" -eq 0 ] && [ "$X_FAILED" -eq 0 ]; then
  echo "No new items."; exit 0
fi

# ---- Generate briefing via Claude API ----
RAW_ITEMS=$(cat "$NEW_ITEMS_FILE")
[ -z "$RAW_ITEMS" ] && RAW_ITEMS="(신규 항목 없음)"
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

BRIEFING=""
if [ "$NEW_COUNT" -gt 0 ]; then
  BRIEFING_RESPONSE=$(curl -s --connect-timeout 10 -m 120 -X POST "https://api.anthropic.com/v1/messages" \
    -H "x-api-key: ${ANTHROPIC_API_KEY:-}" -H "anthropic-version: 2023-06-01" -H "content-type: application/json" \
    -d "$(jq -n --arg system "$SYSTEM_PROMPT" --arg items "$RAW_ITEMS" \
      '{model:"claude-haiku-4-5-20251001",max_tokens:2048,system:$system,messages:[{role:"user",content:("다음 항목들로 브리핑을 작성해줘:\n\n"+$items)}]}')" 2>&1) || true
  if echo "$BRIEFING_RESPONSE" | jq -e '.content[0].text' >/dev/null 2>&1; then
    BRIEFING=$(echo "$BRIEFING_RESPONSE" | jq -r '.content[0].text')
  else
    echo "  Claude API failed: $(echo "$BRIEFING_RESPONSE" | head -c 200)"
    BRIEFING="⚠️ AI 요약 생성 실패\n\n원본:\n${RAW_ITEMS}"
  fi
fi

# Surface X total-failure in the briefing itself (not just stderr).
if [ "$X_FAILED" -eq 1 ]; then
  BRIEFING="${BRIEFING}

⚠️ *X 수집 실패* — query_id 갱신 또는 x.com 재로그인 필요 (.briefing-state/collect.log 참고)"
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
