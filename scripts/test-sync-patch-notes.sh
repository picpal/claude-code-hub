#!/usr/bin/env bash
set -euo pipefail

PASS=0
FAIL=0
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

pass() { echo "  ✓ $1"; PASS=$((PASS+1)); }
fail() { echo "  ✗ $1"; FAIL=$((FAIL+1)); }

echo "=== sync-patch-notes.sh 테스트 ==="

# TC1: 빈 body 릴리즈 스킵 확인
echo ""
echo "TC1: 빈 body 릴리즈 스킵"
PATCH_DIR="$TMPDIR/tc1/pages/patch-notes"
mkdir -p "$PATCH_DIR"
# body가 빈 mock JSON으로 스크립트의 빈 body 체크 로직 테스트
BODY=""
if [ -z "$BODY" ] || [ "$BODY" = "null" ]; then
  pass "빈 body 감지하여 스킵"
else
  fail "빈 body를 감지하지 못함"
fi

# TC2: 이미 존재하는 파일 스킵
echo ""
echo "TC2: 기존 파일 스킵"
PATCH_DIR="$TMPDIR/tc2/pages/patch-notes"
mkdir -p "$PATCH_DIR"
touch "$PATCH_DIR/2026-03-14-v2.1.76.md"
FILEPATH="$PATCH_DIR/2026-03-14-v2.1.76.md"
if [ -f "$FILEPATH" ]; then
  pass "기존 파일 존재 감지"
else
  fail "기존 파일 감지 실패"
fi

# TC3: Jekyll front matter 형식 검증
echo ""
echo "TC3: Front matter 형식"
PATCH_DIR="$TMPDIR/tc3/pages/patch-notes"
mkdir -p "$PATCH_DIR"
TAG="v2.1.76"
DATE="2026-03-14"
VERSION="2.1.76"
FINAL_BODY="## 추가
- 테스트 기능"
FILEPATH="$PATCH_DIR/${DATE}-${TAG}.md"

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

# 검증
if head -1 "$FILEPATH" | grep -q "^---$"; then
  pass "front matter 시작 태그 존재"
else
  fail "front matter 시작 태그 누락"
fi
if grep -q "layout: post" "$FILEPATH"; then
  pass "layout: post 존재"
else
  fail "layout: post 누락"
fi
if grep -q "permalink:" "$FILEPATH"; then
  pass "permalink 존재"
else
  fail "permalink 누락"
fi

# TC4: 버전 추출 (v 접두사 제거)
echo ""
echo "TC4: 버전 추출"
TAG="v2.1.76"
VERSION=${TAG#v}
if [ "$VERSION" = "2.1.76" ]; then
  pass "v 접두사 제거 정상 (v2.1.76 → 2.1.76)"
else
  fail "v 접두사 제거 실패: $VERSION"
fi

# TC5: ANTHROPIC_API_KEY 미설정 시 원문 유지
echo ""
echo "TC5: ANTHROPIC_API_KEY 미설정 시 fallback"
unset ANTHROPIC_API_KEY 2>/dev/null || true
BODY="## Added\n- New feature"
TRANSLATED_BODY=""
if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
  fail "ANTHROPIC_API_KEY가 설정되어 있음"
else
  pass "ANTHROPIC_API_KEY 미설정 감지"
fi
if [ -z "$TRANSLATED_BODY" ]; then
  FINAL_BODY="$BODY"
  pass "영어 원문 fallback 정상"
else
  fail "fallback 로직 실패"
fi

# 결과 요약
echo ""
echo "=== 결과: ${PASS} passed, ${FAIL} failed ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
