---
layout: post
title: Getting Started
description: Claude Code를 처음 사용하는 분을 위한 시작 가이드
permalink: /pages/resources/getting-started/
---

## 목차
- [Claude Code 입문 치트시트](#claude-code-입문-치트시트)
- [1. 초기 설정  CLAUDE.md](#1-초기-설정--claudemd)
- [2. 키보드 단축키  네비게이션](#2-키보드-단축키--네비게이션)
- [3. 필수 슬래시 명령어](#3-필수-슬래시-명령어)
- [4. Quick Reference](#4-quick-reference)

---

## Claude Code 입문 치트시트

Claude Code를 처음 사용하는 분을 위한 핵심 가이드입니다. 초기 설정부터 자주 쓰는 단축키, 슬래시 명령어까지 한 페이지에 정리했습니다.

---

## 1. 초기 설정 & CLAUDE.md

### 시작하기

프로젝트 루트 디렉토리에서 Claude Code를 실행합니다.

```bash
cd your-project
claude
```

최초 실행 후 `/init` 명령으로 `CLAUDE.md` 파일을 자동 생성할 수 있습니다.

```
/init
```

### CLAUDE.md 계층 구조

CLAUDE.md는 두 가지 레벨로 관리됩니다.

| 위치 | 역할 | 예시 내용 |
|------|------|-----------|
| `~/.claude/CLAUDE.md` | 글로벌 (모든 프로젝트 공통) | 공통 코딩 스타일, 선호하는 언어 설정 |
| `프로젝트루트/CLAUDE.md` | 프로젝트별 | 아키텍처, 빌드 명령어, 컨벤션 |

### CLAUDE.md에 넣어야 할 내용

- **절대 규칙** -- 반드시 지켜야 하는 원칙 (예: "테스트 없이 커밋 금지")
- **아키텍처** -- 프로젝트 구조, 주요 모듈 설명
- **빌드/테스트 명령어** -- `npm run build`, `npm test` 등 자주 쓰는 명령
- **도메인 컨텍스트** -- 비즈니스 로직, 용어 정의
- **코딩 컨벤션** -- 네이밍, 폴더 구조, 패턴

> CLAUDE.md는 **300줄 이하**로 유지하세요. 너무 길면 토큰을 낭비하고 오히려 핵심이 희석됩니다.

<details>
<summary>CLAUDE.md 작성 꿀팁</summary>

- **규칙 우선순위**: 파일 위쪽에 적은 규칙일수록 우선순위가 높습니다. 중요한 규칙을 먼저 적으세요.
- **Claude에게 추가 시키기**: "이 규칙을 CLAUDE.md에 추가해줘"라고 하면 Claude가 직접 파일을 수정합니다.
- **트리거 키워드**: 특정 상황에서 자동으로 적용되는 규칙을 키워드로 설정할 수 있습니다. (예: "리팩토링 시 반드시 테스트 먼저 작성")
- **팀 공유**: CLAUDE.md를 Git에 커밋하면 팀 전체가 동일한 컨텍스트를 공유할 수 있습니다.

</details>

---

## 2. 키보드 단축키 & 네비게이션

### 핵심 단축키

**Shift + Tab** -- Plan Mode와 Accept Mode를 전환합니다.

- **Plan Mode**: Claude가 계획만 세우고 실행하지 않습니다.
- **Accept Mode**: Claude가 계획을 세우고 바로 실행합니다.

> 새로운 작업을 시작할 때는 **Plan Mode로 먼저 시작**하는 것을 권장합니다. 계획을 확인한 뒤 Accept Mode로 전환하세요.

**Escape** -- 현재 진행 중인 작업을 즉시 중단합니다.

**Escape x 2** -- 입력 중인 텍스트를 삭제하거나 복원합니다.

### 이미지 입력

스크린샷을 터미널에 **드래그 앤 드롭**하면 Claude가 이미지를 인식하고 분석합니다. UI 버그 리포트나 디자인 참고에 유용합니다.

### iTerm2 패널 활용

iTerm2를 사용한다면 패널 분할로 Claude Code와 다른 작업을 동시에 진행할 수 있습니다.

| 단축키 | 동작 |
|--------|------|
| `Cmd + D` | 세로 분할 |
| `Cmd + Shift + D` | 가로 분할 |
| `Cmd + [` / `Cmd + ]` | 패널 간 이동 |

### Bash 명령 빠른 실행

`!` 접두사를 붙이면 Claude 대화 안에서 바로 bash 명령을 실행할 수 있습니다.

```
!npm run build
!git status
!ls -la
```

---

## 3. 필수 슬래시 명령어

### 자주 쓰는 명령어

| 명령어 | 설명 | 사용 시점 |
|--------|------|-----------|
| `/clear` | 컨텍스트 초기화 | 새 작업을 시작할 때 |
| `/context` | 토큰 사용량 확인 | 응답이 느려질 때 |
| `/compact` | 컨텍스트 압축 (맥락 유지) | 토큰 80% 이상 사용 시 |
| `/models` | 모델 전환 | 작업 난이도에 따라 |
| `/resume` | 이전 세션 복구 | 작업 이어서 할 때 |
| `/mcp` | MCP 서버 관리 | 외부 도구 연결/해제 |

> `/context`로 토큰 사용량을 확인했을 때 **80% 이상**이면 `/clear`로 초기화하거나 `/compact`로 압축하세요.

### 모델 선택 가이드

`/models` 명령으로 상황에 맞는 모델을 선택합니다.

| 모델 | 적합한 작업 |
|------|-------------|
| **Opus** | 복잡한 아키텍처 변경, 다중 파일 수정, 보안 로직 |
| **Sonnet** | 일반적인 기능 구현, 코드 리뷰 |
| **Haiku** | 간단한 질문, 문서 수정, 단일 파일 변경 |

### 기타 명령어

| 명령어 | 설명 |
|--------|------|
| `/help` | 도움말 표시 |
| `/config` | 설정 확인 및 변경 |
| `/export` | 대화 내용 내보내기 |
| `/output-style` | 출력 스타일 변경 |

### 커스텀 명령어 만들기

`.claude/commands/` 폴더에 `.md` 파일을 생성하면 나만의 슬래시 명령어를 만들 수 있습니다.

```
프로젝트루트/
  .claude/
    commands/
      review.md      → /review 명령으로 사용
      test-all.md    → /test-all 명령으로 사용
```

---

## 4. Quick Reference

### 단축키 Quick Reference

| 단축키 | 동작 |
|--------|------|
| `Shift + Tab` | Plan Mode / Accept Mode 전환 |
| `Escape` | 작업 즉시 중단 |
| `Escape x 2` | 입력 삭제/복원 |
| `Cmd + D` | iTerm 세로 분할 |
| `Cmd + Shift + D` | iTerm 가로 분할 |
| `Cmd + [` / `]` | iTerm 패널 이동 |

### 명령어 Quick Reference

| 명령어 | 동작 |
|--------|------|
| `/init` | CLAUDE.md 자동 생성 |
| `/clear` | 컨텍스트 초기화 |
| `/compact` | 컨텍스트 압축 |
| `/context` | 토큰 사용량 확인 |
| `/models` | 모델 전환 |
| `/resume` | 이전 세션 복구 |
| `/mcp` | MCP 서버 관리 |
| `/help` | 도움말 |
| `/config` | 설정 변경 |
| `/export` | 대화 내보내기 |
| `!명령어` | bash 명령 실행 |
