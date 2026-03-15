#!/usr/bin/env bash
set -euo pipefail

REPO="anthropics/claude-code"
PATCH_DIR="pages/patch-notes"
# DeepL API URL 자동 감지 (Free 키는 :fx로 끝남)
if [[ "${DEEPL_API_KEY:-}" == *":fx" ]]; then
  DEEPL_URL="https://api-free.deepl.com/v2/translate"
else
  DEEPL_URL="https://api.deepl.com/v2/translate"
fi

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

echo "$RELEASES" | jq -c '.[]' | while read -r release; do
  TAG=$(echo "$release" | jq -r '.tag_name')
  DATE=$(echo "$release" | jq -r '.published_at' | cut -dT -f1)
  VERSION=${TAG#v}
  BODY=$(echo "$release" | jq -r '.body // ""')
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

  # DeepL 번역 시도
  TRANSLATED_BODY=""
  if [ -n "${DEEPL_API_KEY:-}" ] && [ -n "$BODY" ]; then
    echo "Translating: $FILENAME (${#BODY} chars) via $DEEPL_URL"
    # 각 줄을 JSON 배열로 변환하여 개별 번역 (줄바꿈 보존)
    TEXT_ARRAY=$(echo "$BODY" | jq -R -s 'split("\n") | map(select(length > 0))' )
    DEEPL_RESPONSE=$(curl -s --connect-timeout 10 -m 120 \
      -X POST "$DEEPL_URL" \
      -H "Authorization: DeepL-Auth-Key ${DEEPL_API_KEY}" \
      -H "Content-Type: application/json" \
      -d "$(jq -n --argjson texts "$TEXT_ARRAY" --arg lang "KO" \
        '{text: $texts, target_lang: $lang}')" \
      2>&1) || true

    if echo "$DEEPL_RESPONSE" | jq -e '.translations' > /dev/null 2>&1; then
      TRANSLATED_BODY=$(echo "$DEEPL_RESPONSE" | jq -r '[.translations[].text] | join("\n")')
      echo "  Translation OK (${#TRANSLATED_BODY} chars)"
    else
      echo "  Translation FAILED: $(echo "$DEEPL_RESPONSE" | head -c 200)"
    fi
  fi

  if [ -n "$TRANSLATED_BODY" ]; then
    FINAL_BODY="$TRANSLATED_BODY"
  else
    FINAL_BODY="$BODY"
  fi

  # 섹션 헤더 한국어 변환
  FINAL_BODY=$(echo "$FINAL_BODY" | sed \
    -e 's/^## [Aa]dded/## 추가/' \
    -e 's/^## [Ff]ixed/## 수정/' \
    -e 's/^## [Cc]hanged/## 변경/' \
    -e 's/^## [Rr]emoved/## 제거/' \
    -e 's/^## [Dd]eprecated/## 폐기/' \
    -e "s/^## [Ww]hat's [Cc]hanged/## 변경사항/" \
    -e 's/^## [Nn]ew [Ff]eatures/## 새 기능/' \
    -e 's/^## [Bb]ug [Ff]ixes/## 버그 수정/' \
    -e 's/^## [Bb]reaking [Cc]hanges/## 주요 변경/')

  cat > "$FILEPATH" <<EOF
---
layout: post
title: "${TAG}"
date: ${DATE}
version: "${VERSION}"
permalink: /pages/patch-notes/${DATE}-${TAG}/
---

${FINAL_BODY}
EOF

  echo "Created: $FILENAME"
done
