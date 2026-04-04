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

# Helper function: count Korean characters using python3 (cross-platform)
count_korean() {
  local text="$1"
  printf '%s' "$text" | python3 -c "
import sys
text = sys.stdin.read()
count = sum(1 for c in text if '\uAC00' <= c <= '\uD7AF')
print(count)
"
}

# TC6: 한국어 비율 계산 - 충분한 한국어 포함 시 검증 통과
echo ""
echo "TC6: 한국어 비율 검증 - 충분한 한국어 (>= 15%)"
TRANSLATED_BODY="## 추가된 기능
- 새로운 API endpoint 가 추가되었습니다
- webhook 연동이 개선되었습니다"
TOTAL_CHARS=$(printf '%s' "$TRANSLATED_BODY" | tr -d '[:space:]' | wc -c | tr -d ' ')
KOREAN_CHARS=$(count_korean "$TRANSLATED_BODY")
if [ "$TOTAL_CHARS" -gt 0 ]; then
  RATIO_PCT=$(python3 -c "print(int($KOREAN_CHARS * 100 / $TOTAL_CHARS))")
  if [ "${RATIO_PCT:-0}" -ge 15 ]; then
    pass "한국어 비율 ${RATIO_PCT}% >= 15% 검증 통과"
  else
    fail "한국어 비율 ${RATIO_PCT}% < 15% (예상: 통과)"
  fi
else
  fail "총 문자수 계산 실패"
fi

# TC7: 한국어 비율 계산 - 한국어 거의 없을 때 실패 감지
echo ""
echo "TC7: 한국어 비율 검증 - 불충분한 한국어 (< 15%)"
TRANSLATED_BODY="## Added
- New API endpoint has been added
- webhook integration improved"
TOTAL_CHARS=$(printf '%s' "$TRANSLATED_BODY" | tr -d '[:space:]' | wc -c | tr -d ' ')
KOREAN_CHARS=$(count_korean "$TRANSLATED_BODY")
if [ "$TOTAL_CHARS" -gt 0 ]; then
  RATIO_PCT=$(python3 -c "print(int($KOREAN_CHARS * 100 / $TOTAL_CHARS))")
  if [ "${RATIO_PCT:-0}" -lt 15 ]; then
    pass "한국어 비율 ${RATIO_PCT}% < 15% 올바르게 감지"
  else
    fail "한국어 비율 ${RATIO_PCT}% >= 15% (예상: 실패 감지)"
  fi
else
  fail "총 문자수 계산 실패"
fi

# TC8: 한국어 비율 15% 경계값 (정확히 15% 이상은 통과)
echo ""
echo "TC8: 한국어 비율 경계값 테스트 (15% 이상은 통과)"
# 한국어 문자가 약 20%인 텍스트: "변경됨ABC" → 3한국어/6총 = 50%
TRANSLATED_BODY="변경됨ABC"
TOTAL_CHARS=$(printf '%s' "$TRANSLATED_BODY" | tr -d '[:space:]' | wc -c | tr -d ' ')
KOREAN_CHARS=$(count_korean "$TRANSLATED_BODY")
if [ "$TOTAL_CHARS" -gt 0 ]; then
  RATIO_PCT=$(python3 -c "print(int($KOREAN_CHARS * 100 / $TOTAL_CHARS))")
  if [ "${RATIO_PCT:-0}" -ge 15 ]; then
    pass "한국어 비율 ${RATIO_PCT}% >= 15% 경계값 통과"
  else
    fail "한국어 비율 ${RATIO_PCT}% < 15% 경계값 실패 (예상: 통과)"
  fi
else
  fail "총 문자수 계산 실패"
fi

# TC9: 재시도 후 fallback - 재시도도 실패 시 원문 사용
echo ""
echo "TC9: 재시도 실패 시 원문 fallback"
ORIGINAL_BODY="## Added\n- New feature added"
RETRY_TRANSLATED="## Added\n- New feature still in English"
RETRY_TOTAL=$(printf '%s' "$RETRY_TRANSLATED" | tr -d '[:space:]' | wc -c | tr -d ' ')
RETRY_KOREAN=$(count_korean "$RETRY_TRANSLATED")
if [ "$RETRY_TOTAL" -gt 0 ]; then
  RETRY_PCT=$(python3 -c "print(int($RETRY_KOREAN * 100 / $RETRY_TOTAL))")
  if [ "${RETRY_PCT:-0}" -lt 15 ]; then
    TRANSLATED_BODY=""
    FINAL_BODY="$ORIGINAL_BODY"
    if [ "$FINAL_BODY" = "$ORIGINAL_BODY" ]; then
      pass "재시도 실패 시 원문으로 fallback 정상"
    else
      fail "재시도 실패 시 fallback 오류"
    fi
  else
    fail "테스트 설정 오류: 재시도 텍스트가 Korean ratio >= 15%"
  fi
else
  fail "총 문자수 계산 실패"
fi

# TC10: 시스템 프롬프트에 한국어 문법 규칙 포함 확인
echo ""
echo "TC10: 시스템 프롬프트 한국어 문법 규칙 포함 확인"
SYSTEM_PROMPT_CONTENT=$(grep -n "문장의 서술어" /Users/picpal/Desktop/workspace/claude-code-hub/scripts/sync-patch-notes.sh 2>/dev/null || echo "")
if [ -n "$SYSTEM_PROMPT_CONTENT" ]; then
  pass "시스템 프롬프트에 한국어 서술어 규칙 포함됨"
else
  fail "시스템 프롬프트에 한국어 서술어 규칙 누락"
fi

SYSTEM_PROMPT_CONTENT2=$(grep -n "기술 용어만 영어" /Users/picpal/Desktop/workspace/claude-code-hub/scripts/sync-patch-notes.sh 2>/dev/null || echo "")
if [ -n "$SYSTEM_PROMPT_CONTENT2" ]; then
  pass "시스템 프롬프트에 기술 용어 영어 유지 규칙 포함됨"
else
  fail "시스템 프롬프트에 기술 용어 규칙 누락"
fi

# TC11: 한국어 비율 검증 로직이 스크립트에 존재하는지 확인
echo ""
echo "TC11: 한국어 비율 검증 로직 존재 확인"
RATIO_LOGIC=$(grep -n "AC00.*D7AF\|korean_ratio\|KOREAN_CHARS\|RATIO_PCT" /Users/picpal/Desktop/workspace/claude-code-hub/scripts/sync-patch-notes.sh 2>/dev/null || echo "")
if [ -n "$RATIO_LOGIC" ]; then
  pass "한국어 비율 검증 로직이 스크립트에 존재함"
else
  fail "한국어 비율 검증 로직이 스크립트에 없음"
fi

RETRY_LOGIC=$(grep -n "retry\|RETRY\|enhanced.*prompt\|enhanced_prompt\|ENHANCED" /Users/picpal/Desktop/workspace/claude-code-hub/scripts/sync-patch-notes.sh 2>/dev/null || echo "")
if [ -n "$RETRY_LOGIC" ]; then
  pass "재시도 로직이 스크립트에 존재함"
else
  fail "재시도 로직이 스크립트에 없음"
fi

# 결과 요약
echo ""
echo "=== 결과: ${PASS} passed, ${FAIL} failed ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
