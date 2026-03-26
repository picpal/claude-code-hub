# Implementation Plan

## Overview
DeepL 번역 API를 Claude Haiku (`claude-haiku-4-5-20251001`) Messages API로 교체. 3개 파일 수정. sed 기반 헤더 번역 제거 (프롬프트에서 직접 처리).

## File Changes

### 1. scripts/sync-patch-notes.sh
- **삭제**: lines 6-11 (DeepL URL 자동감지 블록)
- **교체**: lines 47-67 (DeepL API 호출 → Claude Haiku API 호출)
  - `DEEPL_API_KEY` → `ANTHROPIC_API_KEY`
  - POST to `https://api.anthropic.com/v1/messages`
  - Headers: `x-api-key`, `anthropic-version: 2023-06-01`, `content-type: application/json`
  - Body: `jq -n` 으로 system prompt + user message 구성
  - Response parsing: `.content[0].text`
- **삭제**: lines 75-85 (sed 기반 헤더 한국어 변환) — 프롬프트에서 처리

### 2. .github/workflows/sync-patch-notes.yml
- line 68: `DEEPL_API_KEY: ${{ secrets.DEEPL_API_KEY }}` → `ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}`

### 3. scripts/test-sync-patch-notes.sh
- **삭제**: TC2 (sed 헤더 변환 테스트) — 더 이상 필요 없음
- **수정**: TC6에서 `DEEPL_API_KEY` → `ANTHROPIC_API_KEY`
- TC 번호 재정렬

## Translation Prompt Design

**System prompt:**
```
You are a professional translator. Translate the following GitHub release notes from English to Korean (한국어).

Rules:
- Use formal/official tone (공식적인 어조)
- Translate section headers naturally (e.g., "## Added" → "## 추가", "## Fixed" → "## 수정", "## Changed" → "## 변경", "## Removed" → "## 제거", "## Deprecated" → "## 폐기", "## What's Changed" → "## 변경사항", "## New Features" → "## 새 기능", "## Bug Fixes" → "## 버그 수정", "## Breaking Changes" → "## 주요 변경")
- Keep all development/technical terms in English as-is (e.g., API, webhook, endpoint, CLI, SDK, token, prompt, model, MCP, LSP, IDE, Git, SSH, JSON, YAML, Markdown, etc.)
- Preserve all Markdown formatting exactly (headers, lists, code blocks, links, bold, italic)
- Preserve all URLs, code snippets, and file paths exactly as-is
- Do not add any commentary or explanation — output ONLY the translated text
```

**User message:** `$BODY` (원문 release notes markdown)

## API Call Structure
```bash
curl -s --connect-timeout 10 -m 120 \
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
    }')"
```

## Fallback Strategy
- `ANTHROPIC_API_KEY` 미설정 → 번역 스킵, 영어 원문 사용
- API 호출 실패 → `|| true`로 스크립트 중단 방지, 영어 원문 사용
- 에러 응답 → `jq -e` 검증 실패, 영어 원문 사용

## Risks & Mitigations
- 헤더 번역 일관성: 프롬프트에 명시적 매핑 예시 포함
- 토큰 제한: 4096 max_tokens, 일반 패치노트 충분
- GitHub secrets: `ANTHROPIC_API_KEY` 수동 등록 필요 (배포 전 필수)
