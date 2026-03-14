---
layout: post
title: Getting Started
description: Claude Code를 처음 사용하는 분을 위한 시작 가이드
permalink: /pages/resources/getting-started
---

## 설치

```bash
npm install -g @anthropic-ai/claude-code
```

## 기본 사용법

터미널에서 프로젝트 디렉토리로 이동 후:

```bash
claude
```

## 주요 개념

### CLAUDE.md
프로젝트 루트에 `CLAUDE.md` 파일을 생성하면 Claude Code가 프로젝트 컨텍스트를 자동으로 읽습니다.

### Permission Modes
- **Default**: 매 도구 호출마다 확인
- **Auto**: 안전한 작업은 자동 승인
- **Bypass**: 모든 작업 자동 승인 (주의)

### Slash Commands
- `/help` - 도움말
- `/clear` - 대화 초기화
- `/compact` - 컨텍스트 압축
- `/commit` - 변경사항 커밋

### MCP Servers
`~/.claude/settings.json`에서 MCP 서버를 설정하여 외부 도구를 연결할 수 있습니다.
