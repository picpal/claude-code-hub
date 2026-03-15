#!/usr/bin/env bash
set -euo pipefail

REPO="anthropics/claude-code"
PATCH_DIR="pages/patch-notes"
DEEPL_URL="https://api-free.deepl.com/v2/translate"

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

  if [ -f "$FILEPATH" ]; then
    echo "Skip: $FILENAME already exists"
    continue
  fi

  # DeepL 번역 시도
  TRANSLATED_BODY=""
  if [ -n "${DEEPL_API_KEY:-}" ] && [ -n "$BODY" ]; then
    TRANSLATED_BODY=$(curl -sf --connect-timeout 10 -m 30 \
      -X POST "$DEEPL_URL" \
      -d "auth_key=${DEEPL_API_KEY}" \
      --data-urlencode "text=${BODY}" \
      -d "target_lang=KO" | jq -r '.translations[0].text // ""') || true
  fi

  if [ -n "$TRANSLATED_BODY" ]; then
    FINAL_BODY="$TRANSLATED_BODY"
  else
    FINAL_BODY="$BODY"
  fi

  # 섹션 헤더 한국어 변환
  FINAL_BODY=$(echo "$FINAL_BODY" | sed \
    -e 's/^## Added/## 추가/' \
    -e 's/^## Fixed/## 수정/' \
    -e 's/^## Changed/## 변경/' \
    -e 's/^## Removed/## 제거/' \
    -e 's/^## Deprecated/## 폐기/' \
    -e "s/^## What's Changed/## 변경사항/")

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
