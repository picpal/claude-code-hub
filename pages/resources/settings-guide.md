---
layout: post
title: Settings Guide
description: Claude Code 설정 체계 가이드 — 4단계 설정 범위와 주요 옵션
permalink: /pages/resources/settings-guide/
---

## 목차
- [개요](#개요)
- [설정 범위 (4단계)](#설정-범위-4단계)
- [Managed 설정 배포](#managed-설정-배포)
- [주요 설정 항목](#주요-설정-항목)
- [권한 설정 (Permissions)](#권한-설정-permissions)
- [샌드박스 설정 (Sandbox)](#샌드박스-설정-sandbox)
- [Worktree 설정](#worktree-설정)
- [글로벌 설정](#글로벌-설정)
- [참고 자료](#참고-자료)

---

## 개요

Claude Code는 4단계 설정 범위를 통해 유연한 구성을 지원합니다. 개인 설정부터 Enterprise 관리 정책까지, 각 범위의 설정이 병합되어 적용됩니다.

---

## 설정 범위 (4단계)

우선순위가 높은 순서대로:

| 순위 | 범위 | 위치 | 설명 |
|------|------|------|------|
| 1 (최고) | **Managed** | 시스템 수준 | 서버 관리, MDM, 레지스트리 |
| 2 | **User** | `~/.claude/` | 개인 전역 설정 |
| 3 | **Project** | `.claude/` (Git 커밋) | 프로젝트 공통 설정 |
| 4 (최저) | **Local** | `.claude/settings.local.json` | 개인 프로젝트 설정 (gitignore) |

### 설정 파일 경로

```
~/.claude/settings.json          # User 설정
프로젝트/.claude/settings.json   # Project 설정 (Git 커밋)
프로젝트/.claude/settings.local.json  # Local 설정 (gitignore)
```

---

## Managed 설정 배포

Enterprise/Team 환경에서 관리자가 중앙에서 설정을 배포할 수 있습니다.

### 배포 방법

| 방법 | 플랫폼 | 설명 |
|------|--------|------|
| 서버 관리 | 모든 플랫폼 | claude.ai Admin 콘솔에서 관리 |
| MDM | macOS | `com.anthropic.claudecode` managed preferences (Jamf, Kandji) |
| 레지스트리 | Windows | `HKLM\SOFTWARE\Policies\ClaudeCode` |
| 파일 기반 | 모든 플랫폼 | `managed-settings.json` 파일 |

### Drop-in 디렉토리

`managed-settings.d/` 디렉토리에 여러 설정 파일을 배치하면 systemd 스타일로 병합됩니다. 여러 정책을 모듈별로 분리하여 관리할 수 있습니다.

---

## 주요 설정 항목

### 모델 및 실행

| 설정 키 | 설명 | 예시 값 |
|---------|------|---------|
| `model` | 기본 모델 | `"claude-sonnet-4-6"` |
| `effortLevel` | 사고 깊이 | `"low"`, `"medium"`, `"high"` |
| `alwaysThinkingEnabled` | 확장 사고 기본 활성화 | `true` / `false` |
| `availableModels` | 사용 가능 모델 제한 | 모델 ID 배열 |
| `language` | 응답 언어 | `"ko"`, `"en"` |

### UI 및 경험

| 설정 키 | 설명 | 예시 값 |
|---------|------|---------|
| `outputStyle` | 출력 스타일 조정 | 시스템 프롬프트에 추가 |
| `statusLine` | 상태 줄 커스텀 표시 | 커스텀 표시 설정 |
| `prefersReducedMotion` | 애니메이션 감소 (접근성) | `true` / `false` |
| `showThinkingSummaries` | 확장 사고 요약 표시 | `true` / `false` |
| `voiceEnabled` | 음성 입력 활성화 | `true` / `false` |

### 자동화 및 모드

| 설정 키 | 설명 | 예시 값 |
|---------|------|---------|
| `autoMode` | Auto Mode 분류기 규칙 | 규칙 배열 |
| `disableAutoMode` | Auto Mode 비활성화 | `true` / `false` |
| `autoUpdatesChannel` | 업데이트 채널 | `"stable"`, `"latest"` |

### 메모리 및 저장소

| 설정 키 | 설명 | 예시 값 |
|---------|------|---------|
| `autoMemoryDirectory` | 자동 메모리 저장 경로 | 커스텀 경로 |
| `plansDirectory` | 계획 파일 저장 경로 | 커스텀 경로 |
| `cleanupPeriodDays` | 세션 정리 주기 | `30` (기본값) |

### 인증 및 접근

| 설정 키 | 설명 | 예시 값 |
|---------|------|---------|
| `forceLoginMethod` | 로그인 방식 제한 | 특정 방식 강제 |
| `forceLoginOrgUUID` | 조직 UUID 강제 | 조직 ID |
| `channelsEnabled` | Channels 기능 활성화 (Managed) | `true` / `false` |
| `allowedChannelPlugins` | 허용 채널 플러그인 (Managed) | 플러그인 이름 배열 |

### Git 관련

| 설정 키 | 설명 | 예시 값 |
|---------|------|---------|
| `attribution` | Git 커밋/PR 귀속 설정 | 귀속 설정 객체 |
| `includeGitInstructions` | 시스템 프롬프트에 Git 지침 포함 | `true` / `false` |

---

## 권한 설정 (Permissions)

`permissions` 키에서 도구별 권한을 세밀하게 제어할 수 있습니다.

```json
{
  "permissions": {
    "allow": [
      "Read",
      "Glob",
      "Grep",
      "Bash(npm test*)",
      "Bash(git status)"
    ],
    "ask": [
      "Bash",
      "Edit",
      "Write"
    ],
    "deny": [
      "Bash(rm -rf*)",
      "Bash(git push --force*)"
    ],
    "defaultMode": "default",
    "additionalDirectories": [
      "/shared/libs"
    ]
  }
}
```

### 패턴 문법

- `Tool` — 해당 도구의 모든 사용
- `Tool(specifier)` — 특정 패턴에 매칭되는 사용만
- 예: `Bash(npm test*)` — `npm test`로 시작하는 명령만 허용

---

## 샌드박스 설정 (Sandbox)

Claude Code의 Bash 실행 환경을 격리하여 시스템을 보호합니다.

```json
{
  "sandbox": {
    "enabled": true,
    "failIfUnavailable": false,
    "autoAllowBashIfSandboxed": true,
    "filesystem": {
      "allowWrite": ["/tmp", "${cwd}"],
      "denyWrite": ["/etc", "/usr"],
      "denyRead": ["~/.ssh", "~/.aws/credentials"]
    },
    "network": {
      "allowedDomains": ["api.github.com", "*.npmjs.org"],
      "allowLocalBinding": false
    }
  }
}
```

### 주요 샌드박스 옵션

| 설정 | 설명 |
|------|------|
| `filesystem.allowWrite` | 쓰기 허용 경로 |
| `filesystem.denyWrite` | 쓰기 차단 경로 |
| `filesystem.denyRead` | 읽기 차단 경로 (민감 파일) |
| `network.allowedDomains` | 네트워크 접근 허용 도메인 |
| `network.allowLocalBinding` | 로컬 포트 바인딩 허용 |
| `excludedCommands` | 샌드박스에서 제외할 명령어 |

---

## Worktree 설정

Git worktree 기반 격리 환경의 동작을 설정합니다.

```json
{
  "worktree": {
    "symlinkDirectories": ["node_modules", ".venv"],
    "sparsePaths": ["packages/my-package/**"]
  }
}
```

| 설정 | 설명 |
|------|------|
| `symlinkDirectories` | Worktree에서 심볼릭 링크로 공유할 디렉토리 (중복 방지) |
| `sparsePaths` | 대규모 모노레포에서 필요한 경로만 체크아웃 |

---

## 글로벌 설정

`~/.claude.json` 파일에 저장되는 글로벌 설정입니다.

| 설정 | 설명 | 기본값 |
|------|------|--------|
| `autoConnectIde` | IDE 자동 연결 | - |
| `autoInstallIdeExtension` | IDE 확장 자동 설치 | - |
| `editorMode` | 에디터 모드 | `"normal"` / `"vim"` |
| `showTurnDuration` | 턴 소요 시간 표시 | `false` |
| `terminalProgressBarEnabled` | 터미널 진행 바 표시 | - |
| `teammateMode` | 팀원 모드 | `"auto"` / `"in-process"` / `"tmux"` |

---

## 참고 자료

- [공식 문서: Settings](https://code.claude.com/docs/en/settings)
