---
layout: post
title: MCP Servers
description: Model Context Protocol 서버 설정 가이드
permalink: /pages/resources/mcp-servers
---

## MCP란?

Model Context Protocol(MCP)은 Claude Code가 외부 도구 및 데이터 소스와 연결할 수 있게 해주는 프로토콜입니다.

## 설정 방법

`~/.claude/settings.json`에 MCP 서버를 추가합니다:

```json
{
  "mcpServers": {
    "my-server": {
      "command": "node",
      "args": ["path/to/server.js"],
      "env": {}
    }
  }
}
```

## 인기 MCP 서버

| 서버 | 설명 |
|------|------|
| filesystem | 파일 시스템 접근 |
| github | GitHub API 연동 |
| postgres | PostgreSQL 데이터베이스 |
| slack | Slack 메시지 연동 |
| puppeteer | 브라우저 자동화 |

## 프로젝트별 설정

`.mcp.json` 파일을 프로젝트 루트에 생성하여 프로젝트별 MCP 서버를 설정할 수 있습니다.
