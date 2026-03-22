---
layout: post
title: Discord Integration
description: Discord와 Claude Code 연동 가이드
permalink: /pages/resources/discord-integration/
---

> **Research Preview**: Channels 기능은 Claude Code v2.1.80 이상에서 제공되는 실험적 기능입니다. 절차나 명령어가 향후 변경될 수 있습니다.

## 목차
- [개요](#개요)
- [사전 준비](#사전-준비)
- [Discord Bot 생성](#discord-bot-생성)
- [플러그인 설치 및 설정](#플러그인-설치-및-설정)
- [계정 페어링 및 보안 설정](#계정-페어링-및-보안-설정)
- [사용 방법](#사용-방법)
- [주의사항](#주의사항)
- [트러블슈팅](#트러블슈팅)

---

## 개요

Channels는 MCP 서버를 통해 외부 이벤트를 Claude Code 세션에 푸시하는 기능입니다. Discord 봇을 통해 Discord에서 직접 Claude Code와 대화할 수 있으며, 양방향 통신을 지원합니다.

Discord에서 메시지를 보내면 Claude Code 세션에서 해당 메시지를 처리하고, 결과를 다시 Discord로 응답합니다.

---

## 사전 준비

| 항목 | 요구사항 |
|------|----------|
| Claude Code | v2.1.80 이상 |
| 인증 | claude.ai 계정 로그인 필수 (Console/API key 미지원) |
| 런타임 | Bun 설치 필요 (https://bun.sh) |
| Enterprise | Team/Enterprise의 경우 admin이 channelsEnabled 활성화 필요 |

---

## Discord Bot 생성

### 1. 애플리케이션 생성

[Discord Developer Portal](https://discord.com/developers/applications)에 접속하여 **New Application**을 클릭합니다.

### 2. Bot 토큰 발급

**Bot** 탭에서 Username을 설정하고 **Reset Token**을 클릭하여 토큰을 복사합니다.

### 3. Intent 설정

**Privileged Gateway Intents**에서 **Message Content Intent**를 활성화합니다.

### 4. 권한 설정

**OAuth2 > URL Generator**에서 Scopes로 `bot`을 선택하고, 아래 Bot Permissions를 설정합니다:

| 권한 | 설명 |
|------|------|
| View Channels | 채널 목록 조회 |
| Send Messages | 메시지 전송 |
| Send Messages in Threads | 스레드 메시지 전송 |
| Read Message History | 메시지 히스토리 읽기 |
| Attach Files | 파일 첨부 |
| Add Reactions | 리액션 추가 |

### 5. 봇 초대

생성된 URL을 열어 봇을 서버에 초대합니다.

---

## 플러그인 설치 및 설정

### 플러그인 설치

Claude Code에서 다음 명령어를 실행합니다:

```
/plugin install discord@claude-plugins-official
```

플러그인이 없다고 나올 경우:

```
/plugin marketplace update claude-plugins-official
```

또는:

```
/plugin marketplace add anthropics/claude-plugins-official
```

### 플러그인 활성화

설치 후 플러그인을 활성화합니다:

```
/reload-plugins
```

### 토큰 설정

Discord Bot 토큰을 설정합니다:

```
/discord:configure <your-bot-token>
```

토큰은 `~/.claude/channels/discord/.env`에 저장됩니다. 또는 셸 환경 변수 `DISCORD_BOT_TOKEN`으로도 설정할 수 있습니다.

### 채널 모드로 실행

Claude Code를 채널 모드로 재시작합니다:

```bash
claude --channels plugin:discord@claude-plugins-official
```

---

## 계정 페어링 및 보안 설정

### 페어링

1. Discord에서 봇에게 DM을 전송하면 봇이 페어링 코드를 응답합니다.
2. Claude Code에서 해당 코드를 입력합니다:

```
/discord:access pair <code>
```

### 보안 정책 설정

allowlist 정책을 설정하여 승인된 사용자만 접근할 수 있도록 합니다:

```
/discord:access policy allowlist
```

> **보안 주의**: allowlist 정책을 설정하면 승인된 사용자만 메시지를 보낼 수 있습니다. 미설정 시 누구나 봇에게 메시지를 보낼 수 있으므로 반드시 설정하세요.

---

## 사용 방법

Discord DM 또는 봇이 초대된 채널에서 메시지를 보내면, 메시지가 `<channel source="discord">` 이벤트로 Claude Code 세션에 도착합니다. Claude가 작업을 수행한 후 Discord로 응답하며, 파일 첨부도 가능합니다.

### 사용 예시

```
Discord에서: "프로젝트의 README.md 내용을 요약해줘"
→ Claude Code가 파일을 읽고 요약을 Discord로 전송
```

> 세션이 열려 있는 동안만 메시지를 수신합니다. 항상 켜두려면 백그라운드 프로세스나 persistent 터미널에서 실행하세요.

---

## 주의사항

<details>
<summary>Enterprise 및 Team 플랜 설정</summary>

- Team/Enterprise 플랜은 기본적으로 Channels가 비활성화되어 있습니다.
- Admin이 claude.ai > Admin settings > Claude Code > Channels에서 활성화해야 합니다.
- 또는 managed settings에서 `channelsEnabled: true`를 설정합니다.

</details>

- 권한 승인 프롬프트가 나타나면 터미널에서 로컬 승인이 필요합니다.
- 무인 사용 시 `--dangerously-skip-permissions` 플래그를 사용할 수 있습니다 (신뢰할 수 있는 환경에서만).
- Discord 플러그인 소스코드: [claude-plugins-official/discord](https://github.com/anthropics/claude-plugins-official/tree/main/external_plugins/discord)

---

## 트러블슈팅

| 문제 | 해결 방법 |
|------|-----------|
| 봇이 DM에 응답하지 않음 | Claude Code가 `--channels` 플래그로 실행 중인지 확인 |
| 플러그인을 찾을 수 없음 | `/plugin marketplace update claude-plugins-official` 실행 |
| Bun을 찾을 수 없음 | `bun --version`으로 확인, 없으면 https://bun.sh 에서 설치 |
| Team/Enterprise에서 채널 미작동 | Admin에게 channelsEnabled 활성화 요청 |
| 권한 프롬프트로 세션 중단 | 터미널에서 직접 승인하거나 `--dangerously-skip-permissions` 사용 |
