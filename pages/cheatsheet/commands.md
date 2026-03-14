---
layout: post
title: Commands
description: Claude Code CLI 명령어 정리
permalink: /pages/cheatsheet/commands/
---

## 목차
- [Slash Commands](#slash-commands)
- [/clear vs /compact](#clear-vs-compact)
- [CLI 옵션](#cli-옵션)
- [Agent Types](#agent-types)
- [커스텀 슬래시 명령어](#커스텀-슬래시-명령어)
- [유용한 패턴](#유용한-패턴)

---

## Slash Commands

| 명령어 | 설명 |
|--------|------|
| `/help` | 도움말 표시 |
| `/clear` | 대화 기록 초기화 |
| `/compact` | 대화 컨텍스트 압축 |
| `/commit` | Git 커밋 생성 |
| `/review-pr` | PR 리뷰 |
| `/fast` | Fast 모드 토글 |
| `/context` | 현재 컨텍스트(파일, 폴더) 확인 및 관리 |
| `/models` | 사용 가능한 모델 목록 조회 및 전환 |
| `/resume` | 이전 대화 세션 재개 |
| `/mcp` | MCP(Model Context Protocol) 서버 연결 상태 확인 |
| `/config` | Claude Code 설정 조회 및 변경 |
| `/export` | 현재 대화 내용을 파일로 내보내기 |
| `/output-style` | 응답 출력 스타일(마크다운/텍스트 등) 전환 |

## /clear vs /compact

두 명령어 모두 컨텍스트 관리에 사용되지만 동작 방식이 다릅니다.

| 항목 | `/clear` | `/compact` |
|------|----------|------------|
| 기능 | 대화 기록 전체 삭제 | 대화 기록을 요약본으로 압축 |
| 동작 | 메모리에서 모든 이전 메시지 제거 | AI가 핵심 내용만 추려 요약 후 교체 |
| 컨텍스트 유지 | 유지되지 않음 (완전 초기화) | 핵심 맥락은 유지됨 |
| 토큰 절약 | 전량 절약 | 부분 절약 (요약본만큼 소모) |
| 사용 시점 | 완전히 새로운 주제로 전환할 때 | 긴 대화를 이어가되 비용을 줄이고 싶을 때 |
| 주의사항 | 이전 작업 맥락이 모두 사라짐 | 중요한 세부 정보가 요약에서 누락될 수 있음 |

## CLI 옵션

```bash
# 기본 실행
claude

# 프롬프트와 함께 실행
claude "파일을 분석해줘"

# 파이프로 입력
cat file.py | claude "이 코드를 리뷰해줘"

# 권한 모드 지정
claude --permission-mode auto
claude --permission-mode bypass

# 모델 지정
claude --model sonnet
claude --model opus
```

## Agent Types

| 에이전트 | 용도 |
|----------|------|
| `general-purpose` | 범용 작업 |
| `Explore` | 코드베이스 탐색 |
| `Plan` | 구현 계획 수립 |

## 커스텀 슬래시 명령어

Claude Code는 프로젝트 내 `.claude/commands/` 폴더에 마크다운 파일을 작성하면 슬래시 명령어로 등록됩니다.

### 폴더 구조

```
프로젝트 루트/
└── .claude/
    └── commands/
        ├── review.md        → /review 명령어
        ├── deploy.md        → /deploy 명령어
        └── test-all.md      → /test-all 명령어
```

### 명령어 파일 작성 방법

`.md` 파일 내에 Claude에게 전달할 프롬프트를 자유롭게 작성합니다.

```markdown
<!-- .claude/commands/review.md -->
현재 변경된 파일들을 검토하고 다음 기준으로 코드 리뷰를 수행해줘:
1. 잠재적 버그 여부
2. 코드 가독성
3. 성능 이슈
4. 보안 취약점
리뷰 결과는 심각도(높음/중간/낮음)별로 분류해서 알려줘.
```

### 활용 팁

| 항목 | 설명 |
|------|------|
| 파일명 규칙 | 파일명이 그대로 명령어 이름이 됨 (`review.md` → `/review`) |
| 인자 전달 | 명령어 뒤에 텍스트를 추가하면 `$ARGUMENTS`로 전달 가능 |
| 전역 명령어 | `~/.claude/commands/`에 저장하면 모든 프로젝트에서 사용 가능 |
| 프로젝트 공유 | `.claude/` 폴더를 git에 커밋하면 팀원과 명령어 공유 가능 |

## 유용한 패턴

```bash
# 현재 디렉토리의 프로젝트 구조 파악
claude "프로젝트 구조를 설명해줘"

# 특정 파일 수정
claude "src/app.ts에서 에러 핸들링을 추가해줘"

# 테스트 작성
claude "이 함수에 대한 유닛 테스트를 작성해줘"
```
