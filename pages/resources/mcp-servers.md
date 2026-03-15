---
layout: post
title: MCP Servers
description: Model Context Protocol 서버 설정 가이드
permalink: /pages/resources/mcp-servers/
---

## 목차
- [MCP란?](#mcp란)
- [전송 방식 (Transport Types)](#전송-방식-transport-types)
- [CLI로 서버 추가하기](#cli로-서버-추가하기)
- [설정 파일로 구성하기](#설정-파일로-구성하기)
- [프로젝트별 설정](#프로젝트별-설정)
- [환경 변수 활용](#환경-변수-활용)
- [서버 관리 명령어](#서버-관리-명령어)
- [인기 MCP 서버](#인기-mcp-서버)
- [접근 제어 정책](#접근-제어-정책)

---

## MCP란?

Model Context Protocol(MCP)은 Claude Code가 외부 도구 및 데이터 소스와 연결할 수 있게 해주는 개방형 프로토콜입니다. MCP 서버를 통해 데이터베이스 조회, API 호출, 파일 시스템 접근, 브라우저 자동화 등 다양한 외부 기능을 Claude Code에 통합할 수 있습니다.

---

## 전송 방식 (Transport Types)

MCP 서버는 세 가지 전송 방식을 지원합니다:

| 전송 방식 | 설명 | 사용 사례 |
|-----------|------|-----------|
| **stdio** | 로컬 프로세스로 실행, 표준 입출력으로 통신 | NPM 패키지, 로컬 도구, Python 스크립트 |
| **http** | HTTP를 통한 원격 서버 통신 (권장) | 원격/호스팅 서비스, SaaS 연동 |
| **sse** | Server-Sent Events 기반 스트리밍 (deprecated) | 레거시 서버 (가능하면 http 사용 권장) |

---

## CLI로 서버 추가하기

### stdio 서버 (로컬)

```bash
# 기본 문법 (-- 구분자 뒤에 서버 명령어)
claude mcp add --transport stdio <이름> -- <명령어> [인자...]

# 예시: Airtable MCP 서버
claude mcp add --transport stdio --env AIRTABLE_API_KEY=YOUR_KEY airtable -- npx -y airtable-mcp-server
```

### http 서버 (원격, 권장)

```bash
# 기본 문법
claude mcp add --transport http <이름> <URL>

# 예시: Notion 연동
claude mcp add --transport http notion https://mcp.notion.com/mcp

# Bearer 토큰 인증
claude mcp add --transport http secure-api https://api.example.com/mcp \
  --header "Authorization: Bearer your-token"
```

### sse 서버 (원격, deprecated)

```bash
# 기본 문법
claude mcp add --transport sse <이름> <URL>

# 예시: Asana 연동
claude mcp add --transport sse asana https://mcp.asana.com/sse

# 인증 헤더 포함
claude mcp add --transport sse private-api https://api.company.com/sse \
  --header "X-API-Key: your-key-here"
```

---

## 설정 파일로 구성하기

`~/.claude/settings.json`에 MCP 서버를 직접 정의할 수 있습니다:

### stdio 서버 설정

```json
{
  "mcpServers": {
    "my-server": {
      "command": "npx",
      "args": ["-y", "my-mcp-server"]
    }
  }
}
```

### http 서버 설정

```json
{
  "mcpServers": {
    "github": {
      "type": "http",
      "url": "https://api.githubcopilot.com/mcp/"
    },
    "sentry": {
      "type": "http",
      "url": "https://mcp.sentry.dev/mcp"
    }
  }
}
```

### sse 서버 설정

```json
{
  "mcpServers": {
    "hosted-service": {
      "type": "sse",
      "url": "https://mcp.example.com/sse"
    }
  }
}
```

---

## 프로젝트별 설정

프로젝트 루트에 `.mcp.json` 파일을 생성하면 해당 프로젝트에서만 사용되는 MCP 서버를 설정할 수 있습니다. 팀원과 공유하기 좋은 방법입니다.

```json
{
  "mcpServers": {
    "project-db": {
      "command": "python",
      "args": ["-m", "mcp_server_db"],
      "env": {
        "DATABASE_URL": "${DATABASE_URL}"
      }
    }
  }
}
```

---

## 환경 변수 활용

MCP 서버 설정에서 환경 변수를 활용하여 민감한 정보를 안전하게 관리할 수 있습니다:

```json
{
  "mcpServers": {
    "database": {
      "command": "python",
      "args": ["-m", "mcp_server_db"],
      "env": {
        "DATABASE_URL": "${DATABASE_URL}",
        "DB_USER": "${DB_USER}",
        "DB_PASSWORD": "${DB_PASSWORD}"
      }
    },
    "api-server": {
      "type": "http",
      "url": "${API_BASE_URL:-https://api.example.com}/mcp",
      "headers": {
        "Authorization": "Bearer ${API_KEY}"
      }
    }
  }
}
```

`${VAR:-기본값}` 구문으로 환경 변수가 없을 때 기본값을 지정할 수 있습니다.

---

## 서버 관리 명령어

```bash
# 등록된 MCP 서버 목록 확인
claude mcp list

# 특정 서버 상세 정보 조회
claude mcp get github

# 서버 제거
claude mcp remove github
```

Claude Code 실행 중에는 `/mcp` 명령어로 현재 연결된 MCP 서버 상태를 확인할 수 있습니다.

---

## 인기 MCP 서버

| 서버 | 설명 | 전송 방식 | 추가 명령어 |
|------|------|-----------|------------|
| filesystem | 파일 시스템 접근 | stdio | `claude mcp add --transport stdio filesystem -- npx -y @modelcontextprotocol/server-filesystem` |
| github | GitHub API 연동 | http | `claude mcp add --transport http github https://api.githubcopilot.com/mcp/` |
| postgres | PostgreSQL DB | stdio | `claude mcp add --transport stdio postgres -- npx -y @modelcontextprotocol/server-postgres` |
| slack | Slack 메시지 연동 | stdio | `claude mcp add --transport stdio slack -- npx -y @anthropic/mcp-server-slack` |
| puppeteer | 브라우저 자동화 | stdio | `claude mcp add --transport stdio puppeteer -- npx -y @anthropic/mcp-server-puppeteer` |
| sentry | 에러 모니터링 | http | `claude mcp add --transport http sentry https://mcp.sentry.dev/mcp` |
| notion | Notion 워크스페이스 | http | `claude mcp add --transport http notion https://mcp.notion.com/mcp` |

---

## 접근 제어 정책

관리자 또는 팀 설정에서 허용/차단 목록을 통해 MCP 서버 접근을 제어할 수 있습니다:

```json
{
  "allowedMcpServers": [
    { "serverName": "github" },
    { "serverName": "sentry" },
    { "serverCommand": ["npx", "-y", "@modelcontextprotocol/server-filesystem"] },
    { "serverUrl": "https://mcp.company.com/*" }
  ],
  "deniedMcpServers": [
    { "serverName": "dangerous-server" },
    { "serverUrl": "https://*.untrusted.com/*" }
  ]
}
```

서버 이름, 명령어, URL 패턴별로 세밀한 접근 제어가 가능합니다.
