---
layout: post
title: Hooks
description: Claude Code 훅(Hook) 시스템 가이드 — 이벤트 기반 자동화
permalink: /pages/resources/hooks/
---

## 목차
- [개요](#개요)
- [훅 핸들러 타입](#훅-핸들러-타입)
- [훅 이벤트 목록](#훅-이벤트-목록)
- [설정 방법](#설정-방법)
- [PreToolUse 의사결정 제어](#pretooluse-의사결정-제어)
- [실전 예제](#실전-예제)
- [설정 위치](#설정-위치)
- [참고 자료](#참고-자료)

---

## 개요

Hooks는 Claude Code의 특정 이벤트가 발생했을 때 자동으로 실행되는 핸들러입니다. 도구 실행 전후에 검증 로직을 넣거나, 세션 시작 시 환경을 초기화하거나, 파일 변경 시 린터를 자동 실행하는 등 다양한 자동화가 가능합니다.

---

## 훅 핸들러 타입

Hooks는 네 가지 핸들러 타입을 지원합니다.

### 1. Command (셸 명령어)

셸 스크립트를 실행합니다. 비동기 실행을 지원하며, bash(macOS/Linux) 또는 PowerShell(Windows)에서 동작합니다.

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "type": "command",
        "command": "npm run lint -- --fix"
      }
    ]
  }
}
```

### 2. HTTP (웹훅)

지정된 URL로 POST 요청을 전송합니다. 헤더에 환경 변수를 사용할 수 있습니다.

```json
{
  "hooks": {
    "SessionStart": [
      {
        "type": "http",
        "url": "https://hooks.example.com/session-start",
        "headers": {
          "Authorization": "Bearer ${HOOK_TOKEN}"
        }
      }
    ]
  }
}
```

### 3. Prompt (LLM 평가)

LLM에게 yes/no 평가를 요청합니다. 조건부 허용/거부 로직에 유용합니다.

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "type": "prompt",
        "prompt": "이 도구 호출이 프로덕션 데이터베이스에 영향을 줄 수 있나요?"
      }
    ]
  }
}
```

### 4. Agent (서브에이전트)

도구 접근 권한이 있는 서브에이전트를 생성하여 복잡한 검증 로직을 수행합니다.

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "type": "agent",
        "prompt": "방금 수정된 파일의 테스트를 실행하고 결과를 보고해주세요"
      }
    ]
  }
}
```

---

## 훅 이벤트 목록

### 세션 이벤트

| 이벤트 | 시점 |
|--------|------|
| `SessionStart` | 세션이 시작될 때 |
| `SessionEnd` | 세션이 종료될 때 |
| `InstructionsLoaded` | CLAUDE.md 등 지시문이 로드된 후 |
| `ConfigChange` | 설정이 변경되었을 때 |

### 도구 이벤트

| 이벤트 | 시점 |
|--------|------|
| `PreToolUse` | 도구 실행 직전 (허용/거부/수정 가능) |
| `PostToolUse` | 도구 실행 직후 |
| `PostToolUseFailure` | 도구 실행 실패 시 |
| `PermissionRequest` | 권한 요청 시 (규칙 추가/제거 가능) |
| `PermissionDenied` | 권한이 거부되었을 때 |

### 사용자 이벤트

| 이벤트 | 시점 |
|--------|------|
| `UserPromptSubmit` | 사용자가 프롬프트를 제출할 때 |

### 에이전트 이벤트

| 이벤트 | 시점 |
|--------|------|
| `SubagentStart` | 서브에이전트가 시작될 때 |
| `SubagentStop` | 서브에이전트가 종료될 때 |
| `TeammateIdle` | 팀원 에이전트가 유휴 상태일 때 |

### 태스크 이벤트

| 이벤트 | 시점 |
|--------|------|
| `TaskCreated` | 태스크가 생성될 때 |
| `TaskCompleted` | 태스크가 완료될 때 |

### 파일/환경 이벤트

| 이벤트 | 시점 |
|--------|------|
| `FileChanged` | 파일이 변경되었을 때 |
| `CwdChanged` | 작업 디렉토리가 변경되었을 때 |
| `WorktreeCreate` | Worktree가 생성되었을 때 |
| `WorktreeRemove` | Worktree가 제거되었을 때 |

### 컨텍스트 이벤트

| 이벤트 | 시점 |
|--------|------|
| `PreCompact` | 컨텍스트 압축 직전 |
| `PostCompact` | 컨텍스트 압축 직후 |
| `Elicitation` | 추가 정보 요청 시 |
| `ElicitationResult` | 추가 정보 응답 수신 시 |

### 기타

| 이벤트 | 시점 |
|--------|------|
| `Notification` | 알림 발생 시 |
| `Stop` | 작업 중단 시 |
| `StopFailure` | 중단 실패 시 |

---

## 설정 방법

`settings.json`의 `hooks` 키에 이벤트별 핸들러 배열을 정의합니다.

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "type": "command",
        "command": "echo '도구 실행 전 검증'"
      }
    ],
    "PostToolUse": [
      {
        "type": "command",
        "command": "npm run lint"
      }
    ],
    "SessionStart": [
      {
        "type": "http",
        "url": "https://hooks.example.com/session"
      }
    ]
  }
}
```

### 조건부 실행 (if 필드)

`if` 필드를 사용하여 특정 조건에서만 훅을 실행할 수 있습니다.

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "type": "command",
        "command": "echo 'Bash 명령어 검증'",
        "if": "{{ tool_name == 'Bash' }}"
      }
    ]
  }
}
```

---

## PreToolUse 의사결정 제어

`PreToolUse` 훅에서는 도구 실행에 대한 의사결정을 제어할 수 있습니다.

### permissionDecision

| 값 | 동작 |
|-----|------|
| `allow` | 도구 실행을 허용 |
| `deny` | 도구 실행을 거부 |
| `ask` | 사용자에게 확인 요청 |
| `defer` | 비대화형 모드에서만 사용, 판단을 미룸 |

### updatedInput

도구의 입력 파라미터를 수정하여 전달할 수 있습니다. 예를 들어, 위험한 명령어를 안전한 버전으로 변환하는 데 사용됩니다.

### PermissionRequest 훅

권한 요청 시 동적으로 규칙을 관리할 수 있습니다.

- `addRules` / `removeRules` — 권한 규칙 추가/제거
- `replaceRules` — 기존 규칙 교체
- `setMode` — 권한 모드 변경
- `addDirectories` / `removeDirectories` — 허용 디렉토리 관리

---

## 실전 예제

### 파일 저장 후 자동 린트

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "type": "command",
        "command": "npx eslint --fix ${file_path}",
        "if": "{{ tool_name == 'Edit' || tool_name == 'Write' }}"
      }
    ]
  }
}
```

### 위험한 Bash 명령어 차단

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "type": "prompt",
        "prompt": "이 bash 명령어가 rm -rf, git push --force 등 위험한 작업을 포함하고 있나요?",
        "if": "{{ tool_name == 'Bash' }}"
      }
    ]
  }
}
```

### 세션 시작 시 Slack 알림

```json
{
  "hooks": {
    "SessionStart": [
      {
        "type": "http",
        "url": "${SLACK_WEBHOOK_URL}",
        "headers": {
          "Content-Type": "application/json"
        }
      }
    ]
  }
}
```

---

## 설정 위치

훅은 여러 위치에서 설정할 수 있으며, 모두 병합되어 적용됩니다.

| 위치 | 파일 | 용도 |
|------|------|------|
| 사용자 설정 | `~/.claude/settings.json` | 개인 전역 훅 |
| 프로젝트 설정 | `.claude/settings.json` | 프로젝트 공통 훅 |
| 로컬 설정 | `.claude/settings.local.json` | 개인 프로젝트 훅 (gitignore) |
| 관리 정책 | `managed-settings.json` | Enterprise 관리자 훅 |
| 플러그인 | `hooks/hooks.json` | 플러그인 번들 훅 |
| 스킬/에이전트 | frontmatter YAML | 스킬별 훅 |

> `allowManagedHooksOnly: true`를 설정하면 관리 정책의 훅만 실행되도록 제한할 수 있습니다.

---

## 참고 자료

- [공식 문서: Hooks](https://code.claude.com/docs/en/hooks)
