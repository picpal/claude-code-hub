---
layout: post
title: Commands
description: Claude Code CLI 명령어 정리
permalink: /pages/cheatsheet/commands/
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

## 유용한 패턴

```bash
# 현재 디렉토리의 프로젝트 구조 파악
claude "프로젝트 구조를 설명해줘"

# 특정 파일 수정
claude "src/app.ts에서 에러 핸들링을 추가해줘"

# 테스트 작성
claude "이 함수에 대한 유닛 테스트를 작성해줘"
```
