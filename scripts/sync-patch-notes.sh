#!/usr/bin/env bash
set -euo pipefail

REPO="anthropics/claude-code"
PATCH_DIR="pages/patch-notes"

FORCE=false
if [ "${1:-}" = "--force" ]; then
  FORCE=true
  echo "Force mode: will regenerate all files"
fi

mkdir -p "$PATCH_DIR"

# GitHub API 폴링
RELEASES=$(curl -sf --connect-timeout 10 -m 30 \
  -H "Accept: application/vnd.github+json" \
  ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
  "https://api.github.com/repos/${REPO}/releases?per_page=10") || { echo "GitHub API failed"; exit 0; }

while read -r release; do
  TAG=$(echo "$release" | jq -r '.tag_name')
  DATE=$(echo "$release" | jq -r '.published_at' | cut -dT -f1)
  VERSION=${TAG#v}
  BODY=$(echo "$release" | jq -r '.body // ""')
  HTML_URL=$(echo "$release" | jq -r '.html_url // ""')
  FILENAME="${DATE}-${TAG}.md"
  FILEPATH="${PATCH_DIR}/${FILENAME}"

  if [ -f "$FILEPATH" ] && [ "$FORCE" = false ]; then
    echo "Skip: $FILENAME already exists"
    continue
  fi

  # 빈 body 스킵
  if [ -z "$BODY" ] || [ "$BODY" = "null" ]; then
    echo "Skip: $FILENAME (empty body)"
    continue
  fi

  # Claude Haiku 번역 시도
  TRANSLATED_BODY=""
  if [ -n "${ANTHROPIC_API_KEY:-}" ] && [ -n "$BODY" ]; then
    echo "Translating: $FILENAME (${#BODY} chars) via Claude Haiku"
    SYSTEM_PROMPT='You are a professional translator. Translate the following GitHub release notes from English to Korean (한국어).

Rules:
- Use formal/official tone (공식적인 어조)
- Translate section headers naturally (e.g., "## Added" → "## 추가", "## Fixed" → "## 수정", "## Changed" → "## 변경", "## Removed" → "## 제거", "## Deprecated" → "## 폐기", "## What'\''s Changed" → "## 변경사항", "## New Features" → "## 새 기능", "## Bug Fixes" → "## 버그 수정", "## Breaking Changes" → "## 주요 변경")
- Keep all development/technical terms in English as-is (e.g., API, webhook, endpoint, CLI, SDK, token, prompt, model, MCP, LSP, IDE, Git, SSH, JSON, YAML, Markdown, etc.)
- Preserve all Markdown formatting exactly (headers, lists, code blocks, links, bold, italic)
- Preserve all URLs, code snippets, and file paths exactly as-is
- Do not add any commentary or explanation — output ONLY the translated text
- 문장의 서술어, 조사, 접속사는 반드시 한국어로 번역할 것 (e.g., "이 추가되었습니다", "을 지원합니다", "및", "또한")
- 기술 용어만 영어로 유지하되, 문장 전체를 영어로 남기지 말 것
- Each bullet point must contain Korean grammar (조사, 서술어) — never leave an entire bullet point in English'
    CLAUDE_RESPONSE=$(curl -s --connect-timeout 10 -m 120 \
      -X POST "https://api.anthropic.com/v1/messages" \
      -H "x-api-key: ${ANTHROPIC_API_KEY}" \
      -H "anthropic-version: 2023-06-01" \
      -H "content-type: application/json" \
      -d "$(jq -n \
        --arg system "$SYSTEM_PROMPT" \
        --arg body "$BODY" \
        '{
          model: "claude-haiku-4-5-20251001",
          max_tokens: 4096,
          system: $system,
          messages: [{role: "user", content: $body}]
        }')" \
      2>&1) || true

    if echo "$CLAUDE_RESPONSE" | jq -e '.content[0].text' > /dev/null 2>&1; then
      TRANSLATED_BODY=$(echo "$CLAUDE_RESPONSE" | jq -r '.content[0].text')
      echo "  Translation OK (${#TRANSLATED_BODY} chars)"

      # Validate Korean content ratio
      TOTAL_CHARS=$(printf '%s' "$TRANSLATED_BODY" | tr -d '[:space:]' | wc -c | tr -d ' ')
      KOREAN_CHARS=$(printf '%s' "$TRANSLATED_BODY" | python3 -c "
import sys
text = sys.stdin.read()
count = sum(1 for c in text if '\uAC00' <= c <= '\uD7AF')
print(count)
")
      RATIO_PCT=0
      if [ "${TOTAL_CHARS:-0}" -gt 0 ]; then
        RATIO_PCT=$(python3 -c "print(int(${KOREAN_CHARS} * 100 / ${TOTAL_CHARS}))")
      fi
      echo "  Korean ratio: ${RATIO_PCT}% (${KOREAN_CHARS}/${TOTAL_CHARS} non-whitespace chars)"

      if [ "${RATIO_PCT:-0}" -lt 15 ]; then
        echo "  WARNING: Low Korean ratio (${RATIO_PCT}% < 15%), retrying with enhanced prompt..."
        ENHANCED_PROMPT='You MUST translate sentence structures to Korean. Only keep technical terms in English. Every bullet point and sentence must use Korean grammar (조사, 서술어). Do NOT leave entire sentences or bullet points in English. Translate the following GitHub release notes to Korean (한국어).'
        RETRY_RESPONSE=$(curl -s --connect-timeout 10 -m 120 \
          -X POST "https://api.anthropic.com/v1/messages" \
          -H "x-api-key: ${ANTHROPIC_API_KEY}" \
          -H "anthropic-version: 2023-06-01" \
          -H "content-type: application/json" \
          -d "$(jq -n \
            --arg system "$ENHANCED_PROMPT" \
            --arg body "$BODY" \
            '{
              model: "claude-haiku-4-5-20251001",
              max_tokens: 4096,
              system: $system,
              messages: [{role: "user", content: $body}]
            }')" \
          2>&1) || true

        if echo "$RETRY_RESPONSE" | jq -e '.content[0].text' > /dev/null 2>&1; then
          RETRY_BODY=$(echo "$RETRY_RESPONSE" | jq -r '.content[0].text')
          RETRY_TOTAL=$(printf '%s' "$RETRY_BODY" | tr -d '[:space:]' | wc -c | tr -d ' ')
          RETRY_KOREAN=$(printf '%s' "$RETRY_BODY" | python3 -c "
import sys
text = sys.stdin.read()
count = sum(1 for c in text if '\uAC00' <= c <= '\uD7AF')
print(count)
")
          RETRY_PCT=0
          if [ "${RETRY_TOTAL:-0}" -gt 0 ]; then
            RETRY_PCT=$(python3 -c "print(int(${RETRY_KOREAN} * 100 / ${RETRY_TOTAL}))")
          fi
          echo "  Retry Korean ratio: ${RETRY_PCT}%"
          if [ "${RETRY_PCT:-0}" -ge 15 ]; then
            TRANSLATED_BODY="$RETRY_BODY"
            echo "  Retry Translation OK (${#TRANSLATED_BODY} chars, ${RETRY_PCT}% Korean)"
          else
            echo "  WARNING: Retry also below Korean threshold (${RETRY_PCT}% < 15%), falling back to English"
            TRANSLATED_BODY=""
          fi
        else
          echo "  Retry Translation FAILED, falling back to English"
          TRANSLATED_BODY=""
        fi
      fi
    else
      echo "  Translation FAILED: $(echo "$CLAUDE_RESPONSE" | head -c 200)"
    fi
  fi

  if [ -n "$TRANSLATED_BODY" ]; then
    FINAL_BODY="$TRANSLATED_BODY"
  else
    FINAL_BODY="$BODY"
  fi

  cat > "$FILEPATH" <<EOF
---
layout: post
title: "${TAG}"
date: ${DATE}
version: "${VERSION}"
permalink: /pages/patch-notes/${DATE}-${TAG}/
---

> 원문: [Claude Code ${TAG} Release Notes](${HTML_URL})

${FINAL_BODY}
EOF

  echo "Created: $FILENAME"
done < <(echo "$RELEASES" | jq -c '.[]')
