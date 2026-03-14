---
layout: post
title: Settings
description: Claude Code 설정 옵션 정리
permalink: /pages/cheatsheet/settings/
---

## 설정 파일 위치

| 파일 | 경로 | 용도 |
|------|------|------|
| 글로벌 설정 | `~/.claude/settings.json` | 전역 설정 |
| 프로젝트 설정 | `.claude/settings.json` | 프로젝트별 설정 |
| MCP 설정 | `~/.claude/settings.json` | MCP 서버 설정 |
| 프로젝트 MCP | `.mcp.json` | 프로젝트별 MCP |

## 주요 설정 옵션

### Permission Mode

```json
{
  "permissions": {
    "default_mode": "default"
  }
}
```

옵션: `default`, `auto`, `bypassPermissions`

### MCP Servers

```json
{
  "mcpServers": {
    "server-name": {
      "command": "node",
      "args": ["server.js"],
      "env": {
        "API_KEY": "..."
      }
    }
  }
}
```

### CLAUDE.md 설정

프로젝트 루트 `CLAUDE.md`:
```markdown
# Project Context

## Build
npm run build

## Test
npm test

## Style
- TypeScript strict mode
- Prefer functional patterns
```

### 메모리 시스템

`~/.claude/projects/<project-hash>/memory/` 디렉토리에 자동 저장됩니다.

```markdown
---
name: memory-name
description: 한 줄 설명
type: user|feedback|project|reference
---

메모리 내용
```
