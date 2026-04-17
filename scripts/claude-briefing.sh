#!/usr/bin/env bash
set -euo pipefail

STATE_DIR=".briefing-state"
SEEN_FILE="${STATE_DIR}/seen-urls.txt"
mkdir -p "$STATE_DIR"
touch "$SEEN_FILE"

NEW_ITEMS_FILE=$(mktemp)
trap 'rm -f "$NEW_ITEMS_FILE"' EXIT
NEW_COUNT=0

is_seen() { grep -qxF "$1" "$SEEN_FILE" 2>/dev/null; }

mark_seen() { echo "$1" >> "$SEEN_FILE"; }

add_item() {
  local source="$1" title="$2" url="$3" summary="${4:-}"
  printf '[%s] %s\n  URL: %s\n  %s\n\n' "$source" "$title" "$url" "$summary" >> "$NEW_ITEMS_FILE"
  mark_seen "$url"
  NEW_COUNT=$((NEW_COUNT + 1))
  echo "  NEW: [$source] $title"
}

# =============================================================
# Source 1: Anthropic Blog (anthropic.com/news)
# =============================================================
echo "=== Fetching Anthropic blog ==="
BLOG_HTML=$(curl -sfL --connect-timeout 10 -m 30 \
  -H "User-Agent: Mozilla/5.0 (compatible; ClaudeCodeHub/1.0)" \
  "https://www.anthropic.com/news" 2>/dev/null || echo "")

if [ -n "$BLOG_HTML" ]; then
  while IFS= read -r path; do
    [ -z "$path" ] && continue
    FULL_URL="https://www.anthropic.com${path}"
    if ! is_seen "$FULL_URL"; then
      SLUG=$(echo "$path" | sed 's|.*/||; s/-/ /g')
      add_item "Anthropic Blog" "$SLUG" "$FULL_URL"
    fi
  done < <(echo "$BLOG_HTML" | grep -oP 'href="\K/news/[^"]+' | sort -u | head -15)
  echo "  Anthropic blog: done"
else
  echo "  Anthropic blog: fetch failed, skipping"
fi

# =============================================================
# Source 2: Claude Blog (claude.com/blog)
# =============================================================
echo "=== Fetching Claude blog ==="
CLAUDE_BLOG_HTML=$(curl -sfL --connect-timeout 10 -m 30 \
  -H "User-Agent: Mozilla/5.0 (compatible; ClaudeCodeHub/1.0)" \
  "https://claude.com/blog" 2>/dev/null || echo "")

if [ -n "$CLAUDE_BLOG_HTML" ]; then
  while IFS= read -r path; do
    [ -z "$path" ] && continue
    FULL_URL="https://claude.com${path}"
    if ! is_seen "$FULL_URL"; then
      SLUG=$(echo "$path" | sed 's|.*/||; s/-/ /g')
      add_item "Claude Blog" "$SLUG" "$FULL_URL"
    fi
  done < <(echo "$CLAUDE_BLOG_HTML" | grep -oP 'href="\K/blog/[^"]+' | sort -u | head -15)
  echo "  Claude blog: done"
else
  echo "  Claude blog: fetch failed, skipping"
fi

# =============================================================
# Source 3: Hacker News (Algolia API)
# =============================================================
echo "=== Fetching Hacker News ==="
TWENTY_FOUR_H_AGO=$(($(date +%s) - 86400))
HN_RESULT=$(curl -sf --connect-timeout 10 -m 30 \
  "https://hn.algolia.com/api/v1/search_by_date?query=claude+anthropic&tags=story&numericFilters=created_at_i>${TWENTY_FOUR_H_AGO}&hitsPerPage=15" \
  2>/dev/null || echo '{"hits":[]}')

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
    add_item "HN (${POINTS}pts, ${COMMENTS}comments)" "$TITLE" "$URL" "Discussion: $HN_URL"
  fi
done < <(echo "$HN_RESULT" | jq -c '.hits[]' 2>/dev/null || true)
echo "  HN: done"

# =============================================================
# Source 4: GitHub Releases (new releases not yet synced)
# =============================================================
echo "=== Checking GitHub releases ==="
RELEASES=$(curl -sf --connect-timeout 10 -m 30 \
  -H "Accept: application/vnd.github+json" \
  ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
  "https://api.github.com/repos/anthropics/claude-code/releases?per_page=5" \
  2>/dev/null || echo "[]")

while read -r release; do
  [ -z "$release" ] || [ "$release" = "null" ] && continue
  TAG=$(echo "$release" | jq -r '.tag_name')
  URL=$(echo "$release" | jq -r '.html_url')
  DATE=$(echo "$release" | jq -r '.published_at' | cut -dT -f1)
  BODY_LINES=$(echo "$release" | jq -r '.body // ""' | head -3 | tr '\n' ' ')

  if ! is_seen "release:${TAG}"; then
    add_item "Release" "${TAG} (${DATE})" "$URL" "$BODY_LINES"
  fi
done < <(echo "$RELEASES" | jq -c '.[]' 2>/dev/null || true)
echo "  Releases: done"

# =============================================================
# First-run detection: seed state without notification
# =============================================================
if [ ! -f "${STATE_DIR}/.seeded" ]; then
  echo "=== First run detected (${NEW_COUNT} new items). Seeding state. ==="
  touch "${STATE_DIR}/.seeded"
  exit 0
fi

# =============================================================
# Nothing new? Exit.
# =============================================================
echo "=== Total new items: $NEW_COUNT ==="
if [ "$NEW_COUNT" -eq 0 ]; then
  echo "No new items. Done."
  exit 0
fi

# =============================================================
# Generate briefing via Claude API
# =============================================================
echo "=== Generating briefing via Claude API ==="
RAW_ITEMS=$(cat "$NEW_ITEMS_FILE")

SYSTEM_PROMPT='You are a Claude ecosystem analyst writing a Slack briefing in Korean (한국어).

Format (Slack mrkdwn):
*📰 오늘의 핵심* — 가장 중요한 1~3건. 각 항목: 제목 + 한 줄 요약 + <url|출처>
*🔧 기술 업데이트* — 릴리스, API 변경. 없으면 생략.
*🌐 커뮤니티 동향* — HN 토론, 주목할 기사. 없으면 생략.
*💡 인사이트* — 관통하는 트렌드/패턴 1~2문장. 사용자 액션 포인트 (있으면).

Rules:
- 한국어로 작성. 기술 용어만 영어 유지.
- Slack mrkdwn: *bold*, <url|title>, \n for newlines, ```code```
- 간결하게 (300단어 이내)
- 섹션에 항목 없으면 해당 섹션 생략
- 끝에 "📊 새 소식 N건" 한 줄 추가'

BRIEFING_RESPONSE=$(curl -s --connect-timeout 10 -m 120 \
  -X POST "https://api.anthropic.com/v1/messages" \
  -H "x-api-key: ${ANTHROPIC_API_KEY}" \
  -H "anthropic-version: 2023-06-01" \
  -H "content-type: application/json" \
  -d "$(jq -n \
    --arg system "$SYSTEM_PROMPT" \
    --arg items "$RAW_ITEMS" \
    '{
      model: "claude-haiku-4-5-20251001",
      max_tokens: 2048,
      system: $system,
      messages: [{role: "user", content: ("다음 항목들로 브리핑을 작성해줘:\n\n" + $items)}]
    }')" 2>&1) || true

BRIEFING=""
if echo "$BRIEFING_RESPONSE" | jq -e '.content[0].text' > /dev/null 2>&1; then
  BRIEFING=$(echo "$BRIEFING_RESPONSE" | jq -r '.content[0].text')
  echo "  Briefing generated (${#BRIEFING} chars)"
else
  echo "  Claude API failed: $(echo "$BRIEFING_RESPONSE" | head -c 200)"
  BRIEFING="⚠️ AI 요약 생성 실패\n\n원본 항목:\n${RAW_ITEMS}"
fi

# =============================================================
# Send to Slack
# =============================================================
echo "=== Sending to Slack ==="
if [ -n "${SLACK_WEBHOOK_URL:-}" ]; then
  SLACK_TEXT="🤖 *Claude Ecosystem Briefing*\n\n${BRIEFING}\n\n🔗 *사이트:* <https://picpal.github.io/claude-code-hub|Claude Code Hub>"
  curl -sf -X POST "$SLACK_WEBHOOK_URL" \
    -H 'Content-type: application/json' \
    -d "$(jq -n --arg text "$SLACK_TEXT" '{text: $text}')" \
    && echo "  Slack notification sent" \
    || echo "  Slack notification failed"
else
  echo "  SLACK_WEBHOOK_URL not set, printing to stdout:"
  echo "---"
  echo -e "$BRIEFING"
  echo "---"
fi

# =============================================================
# Trim state file (keep last 1000 entries)
# =============================================================
if [ "$(wc -l < "$SEEN_FILE" | tr -d ' ')" -gt 1000 ]; then
  tail -800 "$SEEN_FILE" > "${SEEN_FILE}.tmp"
  mv "${SEEN_FILE}.tmp" "$SEEN_FILE"
fi

echo "=== Briefing complete ==="
