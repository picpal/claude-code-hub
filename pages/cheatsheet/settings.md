---
layout: post
title: Settings
description: Claude Code 설정 옵션 정리
permalink: /pages/cheatsheet/settings/
---

## 목차
- [설정 파일 위치](#설정-파일-위치)
- [주요 설정 옵션](#주요-설정-옵션)
- [CLAUDE.md 가이드](#claudemd-가이드)
- [/memory 시스템](#memory-시스템)
- [Lazy Loading 참조 구조](#lazy-loading-참조-구조)

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

## CLAUDE.md 가이드

`CLAUDE.md`는 Claude가 프로젝트를 이해하는 핵심 컨텍스트 파일입니다. 글로벌과 프로젝트 두 계층으로 관리합니다.

### 계층 구조

| 구분 | 경로 | 범위 | 용도 |
|------|------|------|------|
| 글로벌 | `~/.claude/CLAUDE.md` | 전체 프로젝트 | 개인 선호 스타일, 언어 설정 등 |
| 프로젝트 루트 | `./CLAUDE.md` | 해당 프로젝트 전체 | 아키텍처, 빌드/테스트 명령어 등 |
| 서브디렉토리 | `src/auth/CLAUDE.md` 등 | 해당 디렉토리 | 모듈별 세부 규칙 |

글로벌 설정은 프로젝트 설정과 병합되며, 프로젝트 설정이 우선합니다.

### 넣어야 할 내용 5가지

1. **절대 규칙** — Claude가 반드시 지켜야 하는 제약 (예: "프로덕션 DB 직접 수정 금지")
2. **아키텍처** — 디렉토리 구조, 레이어 책임, 핵심 패턴 (예: Repository 패턴 사용)
3. **빌드/테스트** — 빌드·테스트·린트 실행 명령어 (예: `npm run test:unit`)
4. **도메인** — 비즈니스 용어 정의, 주요 엔티티 관계 설명
5. **컨벤션** — 코드 스타일, 네이밍 규칙, 커밋 메시지 형식

### 작성 지침

- **300줄 이하 유지 권장** — 길수록 Claude의 컨텍스트 윈도우를 낭비합니다. 세부 내용은 `@참조` 방식으로 외부 파일로 분리하세요.
- **트리거 키워드 활용** — 특정 상황에서만 로드할 규칙은 트리거 키워드로 감싸면 효율적입니다.

```markdown
# 인증 관련 작업 시 (auth, login, jwt, token 키워드 감지)
- JWT 만료는 1시간, Refresh Token은 7일
- bcrypt 라운드 수 12 이상

# DB 작업 시 (database, query, migration 키워드 감지)
- 마이그레이션 전 반드시 백업 확인
- N+1 쿼리 방지를 위해 관계 데이터는 eager loading 사용
```

---

## /memory 시스템

Claude가 대화 중 학습한 내용을 영구 저장하는 개인 메모리 시스템입니다.

### 저장 위치

```
~/.claude/projects/<project>/memory/MEMORY.md
```

프로젝트별로 격리되며, Claude가 같은 프로젝트 대화를 시작할 때 자동으로 불러옵니다.

### 사용 방법

| 동작 | 명령 | 설명 |
|------|------|------|
| 저장 | "기억해줘" | 현재 맥락·결정·선호를 메모리에 저장 |
| 확인/편집 | `/memory` | 저장된 메모리 내용 확인 및 직접 편집 |

```
사용자: "앞으로 이 프로젝트에서는 에러 처리를 Result 패턴으로 통일해줘. 기억해줘."
Claude: 네, 기억했습니다. 이후 이 프로젝트에서는 Result 패턴을 사용하겠습니다.
```

### 개인 메모리 vs 팀 공유 구분

| 구분 | 저장 위치 | 공유 여부 | 적합한 내용 |
|------|-----------|-----------|------------|
| 개인 메모리 | `/memory` (`~/.claude/...`) | 본인만 | 개인 선호, 작업 스타일, 반복 피드백 |
| 팀 공유 | `CLAUDE.md` (git 관리) | 팀 전체 | 아키텍처 결정, 코드 컨벤션, 도메인 지식 |

팀 전체가 동일한 컨텍스트를 가져야 하는 내용은 반드시 `CLAUDE.md`에 작성하고 커밋하세요. 개인적인 작업 습관이나 선호는 `/memory`에 저장합니다.

---

## Lazy Loading 참조 구조

`CLAUDE.md`에 모든 내용을 직접 작성하면 컨텍스트 윈도우가 낭비됩니다. `@참조` 방식으로 필요한 파일만 로드하는 구조를 권장합니다.

### 나쁜 예: 모든 내용을 CLAUDE.md에 직접 작성

<details>
<summary>펼쳐보기</summary>

<pre><code class="language-markdown"># CLAUDE.md

## API 명세
### 인증 API
- POST /auth/login: { email, password } → { token, refreshToken }
- POST /auth/refresh: { refreshToken } → { token }
- DELETE /auth/logout: Header Authorization Bearer

### 유저 API
- GET /users/:id → UserDto
- PUT /users/:id: { name, email } → UserDto
- DELETE /users/:id → void

## 데이터베이스 스키마
### users 테이블
- id: UUID PRIMARY KEY
- email: VARCHAR(255) UNIQUE NOT NULL
- password_hash: VARCHAR(255) NOT NULL
- created_at: TIMESTAMP DEFAULT NOW()

### 에러 코드 목록
- AUTH_001: 토큰 만료
- AUTH_002: 잘못된 토큰
- USER_001: 유저 없음
... (수백 줄 계속)
</code></pre>

</details>

모든 내용이 항상 로드되어 불필요한 컨텍스트를 차지합니다.

### 좋은 예: @참조로 필요한 파일만 로드

<details>
<summary>펼쳐보기</summary>

<pre><code class="language-markdown"># CLAUDE.md

## 핵심 규칙
- TypeScript strict mode 필수
- 테스트 없는 PR 금지

## 빌드/테스트
- 빌드: `npm run build`
- 테스트: `npm test`
- 린트: `npm run lint`

## 상세 문서 참조
- API 명세: @docs/api-spec.md
- DB 스키마: @docs/database-schema.md
- 에러 코드: @docs/error-codes.md
- 배포 절차: @docs/deployment.md
</code></pre>

</details>

Claude가 API 작업을 할 때만 `@docs/api-spec.md`를 참조하므로, 필요한 시점에 필요한 내용만 로드됩니다.

### 폴더별 CLAUDE.md 분리

모듈이 복잡할수록 해당 디렉토리에 별도 `CLAUDE.md`를 두어 책임을 분리합니다.

```
project/
├── CLAUDE.md                  # 전체 프로젝트 규칙 (간결하게)
├── src/
│   ├── auth/
│   │   └── CLAUDE.md          # 인증 모듈 전용 규칙, JWT 설정
│   ├── payment/
│   │   └── CLAUDE.md          # 결제 모듈 전용 규칙, PCI 준수 사항
│   └── database/
│       └── CLAUDE.md          # DB 레이어 규칙, 마이그레이션 절차
└── docs/
    ├── api-spec.md
    └── database-schema.md
```

Claude는 현재 작업 중인 파일의 경로를 따라 올라가며 관련 `CLAUDE.md`를 자동으로 수집합니다.
