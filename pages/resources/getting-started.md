---
layout: post
title: Getting Started
description: Claude Code를 처음 사용하는 분을 위한 시작 가이드
permalink: /pages/resources/getting-started/
---

## 목차
- [Claude Code 입문 치트시트](#claude-code-입문-치트시트)
- [1. 설치 및 실행 환경](#1-설치-및-실행-환경)
- [2. 초기 설정  CLAUDE.md](#2-초기-설정--claudemd)
- [3. 키보드 단축키  네비게이션](#3-키보드-단축키--네비게이션)
- [4. 권한 모드 및 Auto Mode](#4-권한-모드-및-auto-mode)
- [5. 필수 슬래시 명령어](#5-필수-슬래시-명령어)
- [6. Quick Reference](#6-quick-reference)

---

## Claude Code 입문 치트시트

Claude Code를 처음 사용하는 분을 위한 핵심 가이드입니다. 설치부터 초기 설정, 자주 쓰는 단축키, 슬래시 명령어까지 한 페이지에 정리했습니다.

---

## 1. 설치 및 실행 환경

### 설치 방법

| 플랫폼 | 명령어 |
|--------|--------|
| macOS / Linux | `curl -fsSL https://claude.ai/install.sh \| sh` |
| macOS (Homebrew) | `brew install --cask claude-code` |
| Windows | `winget install Anthropic.ClaudeCode` |

설치 후 `claude` 명령으로 실행합니다. 자동 업데이트를 지원하며, `claude update`로 수동 업데이트도 가능합니다.

### 실행 환경

Claude Code는 다양한 환경에서 사용할 수 있습니다.

| 환경 | 설명 |
|------|------|
| **Terminal CLI** | 기본 실행 환경. 터미널에서 `claude` 명령 실행 |
| **Desktop App** | macOS / Windows용 독립 데스크톱 앱 |
| **Web** | [claude.ai/code](https://claude.ai/code)에서 브라우저로 실행 |
| **VS Code** | VS Code 확장 프로그램으로 IDE 내 실행 |
| **JetBrains** | JetBrains IDE 확장 프로그램 지원 |

### Effort Level

작업 복잡도에 따라 Claude의 사고 깊이를 조절할 수 있습니다.

```bash
claude --effort low     # 간단한 질문, 빠른 응답
claude --effort medium  # 일반적인 작업 (기본값)
claude --effort high    # 복잡한 분석, 깊은 사고
claude --effort max     # 최대 사고 깊이 (Opus 4.6 전용)
```

---

## 2. 초기 설정 & CLAUDE.md

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

<ul>
<li><strong>규칙 우선순위</strong>: 파일 위쪽에 적은 규칙일수록 우선순위가 높습니다. 중요한 규칙을 먼저 적으세요.</li>
<li><strong>Claude에게 추가 시키기</strong>: "이 규칙을 CLAUDE.md에 추가해줘"라고 하면 Claude가 직접 파일을 수정합니다.</li>
<li><strong>트리거 키워드</strong>: 특정 상황에서 자동으로 적용되는 규칙을 키워드로 설정할 수 있습니다. (예: "리팩토링 시 반드시 테스트 먼저 작성")</li>
<li><strong>팀 공유</strong>: CLAUDE.md를 Git에 커밋하면 팀 전체가 동일한 컨텍스트를 공유할 수 있습니다.</li>
</ul>

</details>

---

## 3. 키보드 단축키 & 네비게이션

### 핵심 단축키

**Shift + Tab** -- 권한 모드를 순환 전환합니다.

- **Plan Mode**: Claude가 계획만 세우고 실행하지 않습니다.
- **Accept Edits Mode**: 파일 편집은 자동 허용, 기타 작업은 확인 필요.
- **Auto Mode**: AI 기반 권한 분류기가 자동 판단 (Sonnet 4.6 / Opus 4.6).

> 새로운 작업을 시작할 때는 **Plan Mode로 먼저 시작**하는 것을 권장합니다. 계획을 확인한 뒤 모드를 전환하세요.

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

## 4. 권한 모드 및 Auto Mode

### 권한 모드 (Permission Modes)

Claude Code는 다양한 권한 모드를 제공하여 자율성 수준을 조절할 수 있습니다.

| 모드 | 설명 | CLI 플래그 |
|------|------|-----------|
| **Plan** | 계획만 수립, 실행하지 않음 | `--permission-mode plan` |
| **Default** | 매 작업마다 사용자 승인 필요 | `--permission-mode default` |
| **Accept Edits** | 파일 편집 자동 허용, 기타는 확인 | `--permission-mode acceptEdits` |
| **Auto** | AI가 안전성을 판단하여 자동 승인 | `--permission-mode auto` |
| **Don't Ask** | 대부분의 작업을 자동 실행 | `--permission-mode dontAsk` |
| **Bypass** | 모든 권한 검사 건너뜀 (주의!) | `--permission-mode bypassPermissions` |

> **Auto Mode**는 Sonnet 4.6 또는 Opus 4.6 모델에서만 사용 가능합니다. AI 분류기가 각 작업의 안전성을 판단하여 자동으로 승인/거부합니다.

### Worktree (격리된 작업 환경)

`--worktree` 플래그를 사용하면 Git worktree 기반의 격리된 환경에서 작업할 수 있습니다. 원본 저장소에 영향을 주지 않고 안전하게 실험할 수 있습니다.

```bash
claude --worktree    # 격리된 worktree에서 작업 시작
claude -w            # 단축 플래그
```

### Remote Control & Teleport

- **Remote Control**: `claude --remote-control`로 시작하면 claude.ai나 모바일에서 로컬 세션을 원격 제어할 수 있습니다.
- **Teleport**: `/teleport` 명령으로 웹에서 시작한 세션을 로컬 터미널로 가져올 수 있습니다.

---

## 5. 필수 슬래시 명령어

### 자주 쓰는 명령어

| 명령어 | 설명 | 사용 시점 |
|--------|------|-----------|
| `/clear` | 컨텍스트 초기화 | 새 작업을 시작할 때 |
| `/context` | 토큰 사용량 확인 | 응답이 느려질 때 |
| `/compact` | 컨텍스트 압축 (맥락 유지) | 토큰 80% 이상 사용 시 |
| `/models` | 모델 전환 | 작업 난이도에 따라 |
| `/resume` | 이전 세션 복구 | 작업 이어서 할 때 |
| `/mcp` | MCP 서버 관리 | 외부 도구 연결/해제 |
| `/teleport` | 웹 세션을 로컬로 이동 | 웹에서 시작한 작업 이어할 때 |

> `/context`로 토큰 사용량을 확인했을 때 **80% 이상**이면 `/clear`로 초기화하거나 `/compact`로 압축하세요.

### 모델 선택 가이드

`/models` 명령으로 상황에 맞는 모델을 선택합니다.

| 모델 | 적합한 작업 |
|------|-------------|
| **Opus 4.6** | 복잡한 아키텍처 변경, 다중 파일 수정, 보안 로직 |
| **Sonnet 4.6** | 일반적인 기능 구현, 코드 리뷰 |
| **Haiku 4.5** | 간단한 질문, 문서 수정, 단일 파일 변경 |

> `/fast` 명령으로 Fast Mode를 토글할 수 있습니다. 동일한 모델을 사용하되 더 빠른 출력을 제공합니다.

### 기타 명령어

| 명령어 | 설명 |
|--------|------|
| `/help` | 도움말 표시 |
| `/config` | 설정 확인 및 변경 |
| `/export` | 대화 내용 내보내기 |
| `/output-style` | 출력 스타일 변경 |
| `/fast` | Fast Mode 토글 |
| `/teleport` | 웹 세션을 로컬로 이동 |
| `/plugin` | 플러그인 관리 |
| `/loop` | 반복 실행 설정 |

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

## 6. Quick Reference

### 단축키 Quick Reference

| 단축키 | 동작 |
|--------|------|
| `Shift + Tab` | 권한 모드 순환 전환 (Plan → Accept Edits → Auto) |
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
| `/fast` | Fast Mode 토글 |
| `/teleport` | 웹 세션 → 로컬 이동 |
| `/plugin` | 플러그인 관리 |
| `/loop` | 반복 실행 설정 |
| `!명령어` | bash 명령 실행 |
