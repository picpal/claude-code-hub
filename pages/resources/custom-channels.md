---
layout: post
title: Custom Channels 개발 가이드
description: Claude Code의 커스텀 채널(Custom Channel)을 직접 개발하는 단계별 가이드
permalink: /pages/resources/custom-channels/
---

> **Research Preview**: Channels 기능은 Claude Code v2.1.80 이상에서 제공되는 실험적 기능입니다. API나 구현 방식이 향후 변경될 수 있으므로 프로덕션 환경에서의 사용은 권장하지 않습니다.

## 목차
- [개요](#개요)
- [사전 준비](#사전-준비)
- [Step 1: 플러그인 프로젝트 폴더 구조 만들기](#step-1-플러그인-프로젝트-폴더-구조-만들기)
- [Step 2: plugin.json 작성](#step-2-pluginjson-작성)
- [Step 3: MCP 서버 코드 작성](#step-3-mcp-서버-코드-작성)
- [Step 4: 플러그인 설치 및 채널 모드 실행](#step-4-플러그인-설치-및-채널-모드-실행)
- [Step 5: 테스트 및 확인](#step-5-테스트-및-확인)
- [실전 예제: 웹훅 기반 채널](#실전-예제-웹훅-기반-채널)
- [트러블슈팅](#트러블슈팅)
- [다음 단계 / 참고 자료](#다음-단계--참고-자료)

---

## 개요

Channels는 **MCP(Model Context Protocol) 서버**를 통해 외부 이벤트를 Claude Code 세션에 실시간으로 푸시하는 기능입니다. MCP는 AI 모델과 외부 도구를 연결하는 표준 프로토콜이며, Channels는 이 프로토콜 위에서 **양방향 메시징**을 구현합니다.

쉽게 말해, 여러분이 만든 채널 플러그인이 외부에서 메시지를 받으면 Claude Code 세션으로 전달하고, Claude의 응답을 다시 외부로 보내는 **다리 역할**을 합니다.

### 커스텀 채널이 필요한 경우

- 사내 메신저(예: Mattermost, Zulip)와 Claude Code를 연동하고 싶을 때
- 웹훅(Webhook)으로 들어오는 이벤트를 Claude에게 전달하고 싶을 때
- CI/CD 파이프라인 알림을 Claude가 처리하도록 하고 싶을 때
- 커스텀 웹 인터페이스에서 Claude Code와 소통하고 싶을 때

---

## 사전 준비

| 항목 | 요구사항 |
|------|----------|
| Claude Code | v2.1.80 이상 (`claude --version`으로 확인) |
| 런타임 | Node.js 18+ 또는 Bun (https://bun.sh) |
| 인증 | claude.ai 계정 로그인 필수 (Console/API key 미지원) |
| Channels 활성화 | Team/Enterprise 플랜은 admin이 `channelsEnabled` 활성화 필요 |
| 기본 지식 | JavaScript/TypeScript 기초, JSON 형식 이해 |

> **Enterprise/Team 사용자**: Admin이 claude.ai > Admin settings > Claude Code > Channels에서 기능을 활성화하거나, managed settings에서 `channelsEnabled: true`를 설정해야 합니다.

---

## Step 1: 플러그인 프로젝트 폴더 구조 만들기

커스텀 채널 플러그인의 기본 디렉토리 구조는 다음과 같습니다.

```
my-channel-plugin/
├── plugin.json          # 플러그인 메타데이터 (이름, 버전, 설명)
├── .mcp.json            # MCP 서버 실행 설정 (어떤 명령어로 서버를 시작할지)
├── package.json         # Node.js/Bun 패키지 설정
├── server.ts            # MCP 서버 메인 코드 (채널 로직)
└── tsconfig.json        # TypeScript 설정 (선택사항)
```

터미널에서 프로젝트를 생성합니다.

```bash
mkdir my-channel-plugin
cd my-channel-plugin
```

Bun을 사용하는 경우:

```bash
bun init -y
```

Node.js를 사용하는 경우:

```bash
npm init -y
npm install typescript @types/node --save-dev
npx tsc --init
```

---

## Step 2: plugin.json 작성

`plugin.json`은 Claude Code가 플러그인을 인식하기 위한 메타데이터 파일입니다. 다음 내용으로 작성합니다.

```json
{
  "name": "my-channel",
  "description": "나만의 커스텀 채널 플러그인",
  "version": "0.0.1",
  "keywords": ["channel", "mcp", "custom"]
}
```

| 필드 | 설명 |
|------|------|
| `name` | 플러그인 고유 이름 (영문 소문자, 하이픈 사용 가능) |
| `description` | 플러그인 설명 |
| `version` | 시맨틱 버전 (major.minor.patch) |
| `keywords` | 검색용 키워드 배열. `channel`을 반드시 포함하세요 |

다음으로 `.mcp.json` 파일을 작성합니다. 이 파일은 MCP 서버를 어떤 명령어로 실행할지 정의합니다.

**Bun 사용 시:**

```json
{
  "mcpServers": {
    "my-channel": {
      "command": "bun",
      "args": ["run", "--cwd", "${CLAUDE_PLUGIN_ROOT}", "--shell=bun", "--silent", "start"]
    }
  }
}
```

**Node.js 사용 시:**

```json
{
  "mcpServers": {
    "my-channel": {
      "command": "node",
      "args": ["${CLAUDE_PLUGIN_ROOT}/dist/server.js"]
    }
  }
}
```

> `${CLAUDE_PLUGIN_ROOT}`는 Claude Code가 플러그인 설치 경로로 자동 치환하는 변수입니다. 하드코딩된 경로 대신 반드시 이 변수를 사용하세요.

`package.json`에 start 스크립트를 추가합니다.

```json
{
  "name": "my-channel-plugin",
  "version": "0.0.1",
  "scripts": {
    "start": "bun run server.ts"
  },
  "dependencies": {}
}
```

---

## Step 3: MCP 서버 코드 작성

이 단계가 채널 플러그인의 핵심입니다. MCP 서버는 표준 입출력(stdin/stdout)을 통해 Claude Code와 JSON-RPC 메시지를 주고받습니다.

### 핵심 개념

| 개념 | 설명 |
|------|------|
| **Capability(능력 선언)** | 서버가 `claude/channel` capability를 선언하면 Claude Code가 이 서버를 채널로 인식합니다 |
| **Notification(알림)** | 서버가 `notifications/message`를 통해 외부 메시지를 Claude Code로 푸시합니다 |
| **Tool(도구)** | Claude가 응답할 때 호출하는 함수입니다. `reply` 도구로 외부에 메시지를 보냅니다 |

### 최소 동작 템플릿

아래 코드를 `server.ts`에 복사하면 바로 동작하는 채널 플러그인이 됩니다. 이 템플릿은 **stdin에서 텍스트를 읽어 Claude에게 전달**하고, Claude의 응답을 **stdout으로 출력**하는 에코 채널입니다.

```typescript
import { stdin, stdout } from "process";
import { createInterface } from "readline";

// --- JSON-RPC 헬퍼 ---

/** JSON-RPC 메시지를 stdout으로 전송합니다 */
function send(msg: Record<string, unknown>): void {
  const json = JSON.stringify({ jsonrpc: "2.0", ...msg });
  stdout.write(`Content-Length: ${Buffer.byteLength(json)}\r\n\r\n${json}`);
}

/** 고유 ID를 생성합니다 */
let idCounter = 0;
function nextId(): number {
  return ++idCounter;
}

// --- MCP 프로토콜 메시지 처리 ---

/** 수신된 JSON-RPC 요청을 처리합니다 */
function handleRequest(id: number | string, method: string, params?: any): void {
  switch (method) {
    // 초기화 요청: 서버의 capability(능력)를 선언합니다
    case "initialize":
      send({
        id,
        result: {
          protocolVersion: "2024-11-05",
          capabilities: {
            tools: {},
            // 이 선언이 있어야 Claude Code가 채널로 인식합니다
            experimental: { "claude/channel": {} },
          },
          serverInfo: {
            name: "my-channel",
            version: "0.0.1",
          },
        },
      });
      break;

    // 도구 목록 요청: Claude가 사용할 수 있는 도구를 반환합니다
    case "tools/list":
      send({
        id,
        result: {
          tools: [
            {
              name: "reply",
              description: "채널을 통해 사용자에게 메시지를 전송합니다",
              inputSchema: {
                type: "object",
                properties: {
                  chat_id: {
                    type: "string",
                    description: "대화 식별자",
                  },
                  text: {
                    type: "string",
                    description: "전송할 메시지 내용",
                  },
                },
                required: ["chat_id", "text"],
              },
            },
          ],
        },
      });
      break;

    // 도구 호출 요청: Claude가 reply 도구를 호출하면 실행됩니다
    case "tools/call":
      if (params?.name === "reply") {
        const { chat_id, text } = params.arguments;
        // 여기서 외부 서비스로 메시지를 전송합니다
        // 이 예제에서는 stderr로 출력합니다 (stdout은 MCP 프로토콜 전용)
        process.stderr.write(`[응답 → ${chat_id}] ${text}\n`);
        send({
          id,
          result: {
            content: [{ type: "text", text: "메시지 전송 완료" }],
          },
        });
      } else {
        send({
          id,
          error: { code: -32601, message: `알 수 없는 도구: ${params?.name}` },
        });
      }
      break;

    default:
      send({
        id,
        error: { code: -32601, message: `지원하지 않는 메서드: ${method}` },
      });
  }
}

/** 알림(notification)을 처리합니다. 알림에는 응답이 필요 없습니다 */
function handleNotification(method: string, _params?: any): void {
  if (method === "initialized") {
    // Claude Code와 연결이 완료되었습니다
    process.stderr.write("[채널 서버] 초기화 완료, 메시지 대기 중...\n");
    startListening();
  }
}

// --- 외부 이벤트 수신 및 푸시 ---

/** 외부에서 메시지를 수신하여 Claude Code 세션으로 푸시합니다 */
function pushMessage(chatId: string, user: string, text: string): void {
  send({
    method: "notifications/message",
    params: {
      level: "info",
      // 이 형식이 Claude Code가 채널 메시지로 인식하는 XML 구조입니다
      data: `<channel source="my-channel" chat_id="${chatId}" user="${user}">${text}</channel>`,
    },
  });
}

/** 외부 이벤트 리스너를 시작합니다 (이 예제에서는 stdin 사용) */
function startListening(): void {
  const rl = createInterface({ input: process.stdin });
  // 주의: stdin을 MCP 프로토콜 파서와 공유하지 않도록 별도 스트림을 사용해야 합니다.
  // 실제 채널에서는 WebSocket, HTTP 서버, 메시지 큐 등을 사용합니다.
  // 아래는 개념 설명을 위한 단순화된 예시입니다.
  process.stderr.write("[채널 서버] 외부 이벤트 리스너 시작\n");
}

// --- MCP 프로토콜 파서 (stdin에서 JSON-RPC 메시지를 읽습니다) ---

let buffer = "";

stdin.setEncoding("utf-8");
stdin.on("data", (chunk: string) => {
  buffer += chunk;

  while (true) {
    // Content-Length 헤더를 파싱합니다
    const headerEnd = buffer.indexOf("\r\n\r\n");
    if (headerEnd === -1) break;

    const header = buffer.slice(0, headerEnd);
    const match = header.match(/Content-Length:\s*(\d+)/i);
    if (!match) {
      buffer = buffer.slice(headerEnd + 4);
      continue;
    }

    const contentLength = parseInt(match[1], 10);
    const bodyStart = headerEnd + 4;

    if (buffer.length < bodyStart + contentLength) break;

    const body = buffer.slice(bodyStart, bodyStart + contentLength);
    buffer = buffer.slice(bodyStart + contentLength);

    try {
      const msg = JSON.parse(body);
      if (msg.id !== undefined && msg.method) {
        handleRequest(msg.id, msg.method, msg.params);
      } else if (msg.method && msg.id === undefined) {
        handleNotification(msg.method, msg.params);
      }
    } catch (e) {
      process.stderr.write(`[파싱 오류] ${e}\n`);
    }
  }
});
```

### 코드 구조 요약

```
┌──────────────────────────────────────────────────┐
│                  Claude Code                      │
│                                                    │
│   ① initialize 요청                               │
│   ② tools/list 요청                               │
│   ④ tools/call (reply) 요청                       │
│                                                    │
└─────────────┬──────────────────▲─────────────────┘
              │   stdin/stdout   │
              ▼   (JSON-RPC)    │
┌──────────────────────────────────────────────────┐
│              MCP 서버 (server.ts)                 │
│                                                    │
│   ① capability 선언 (claude/channel)              │
│   ② 도구 목록 반환 (reply)                        │
│   ③ notifications/message로 이벤트 푸시           │
│   ④ reply 도구 호출 → 외부로 메시지 전송          │
│                                                    │
└─────────────┬──────────────────▲─────────────────┘
              │                  │
              ▼                  │
┌──────────────────────────────────────────────────┐
│         외부 서비스 (메신저, 웹훅 등)              │
└──────────────────────────────────────────────────┘
```

### 핵심 포인트

1. **`experimental: { "claude/channel": {} }`** - 이 capability 선언이 없으면 Claude Code는 일반 MCP 서버로 취급하며 채널로 동작하지 않습니다.
2. **`notifications/message`** - 외부 이벤트를 Claude Code로 전달하는 유일한 방법입니다. `data` 필드에 `<channel>` XML 태그를 포함해야 합니다.
3. **`reply` 도구** - Claude가 응답할 때 호출하는 도구입니다. 도구 이름과 파라미터는 자유롭게 설계할 수 있습니다.
4. **stdout은 MCP 전용** - 디버그 출력은 반드시 `stderr`로 보내세요.

---

## Step 4: 플러그인 설치 및 채널 모드 실행

### 로컬 플러그인 설치

개발 중인 플러그인을 로컬에서 설치합니다. Claude Code에서 다음 명령어를 실행하세요.

```bash
/plugin install --local /path/to/my-channel-plugin
```

설치 후 플러그인을 로드합니다.

```
/reload-plugins
```

### 채널 모드로 실행

Claude Code를 채널 모드(`--channels` 플래그)로 시작합니다. 이 플래그가 있어야 채널 플러그인이 활성화됩니다.

```bash
claude --channels plugin:my-channel
```

여러 채널을 동시에 실행할 수도 있습니다.

```bash
claude --channels plugin:my-channel,plugin:discord@claude-plugins-official
```

> `--channels` 플래그 없이 실행하면 채널 플러그인의 MCP 서버가 시작되지 않습니다.

---

## Step 5: 테스트 및 확인

### 동작 확인 체크리스트

| 순서 | 확인 항목 | 확인 방법 |
|------|----------|----------|
| 1 | 플러그인 설치 확인 | `/plugin list`에서 `my-channel`이 보이는지 |
| 2 | MCP 서버 시작 확인 | stderr에 `[채널 서버] 초기화 완료` 메시지 출력 |
| 3 | capability 인식 확인 | Claude Code 시작 시 채널 관련 로그 출력 |
| 4 | 메시지 푸시 확인 | `pushMessage()` 호출 시 Claude가 반응 |
| 5 | reply 도구 동작 확인 | Claude 응답이 외부로 전달되는지 |

### MCP 서버 단독 테스트

플러그인을 설치하기 전에 MCP 서버만 단독으로 테스트할 수 있습니다.

```bash
# 서버를 직접 실행합니다
bun run server.ts
```

다른 터미널에서 JSON-RPC 메시지를 수동으로 전송하여 테스트합니다.

```bash
# initialize 요청 전송 예시
echo 'Content-Length: 109\r\n\r\n{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{}}}' | bun run server.ts
```

### 디버그 로그 확인

MCP 서버의 stderr 출력은 Claude Code의 로그에서 확인할 수 있습니다.

```bash
# Claude Code 로그 파일 위치
cat ~/.claude/logs/mcp-*.log
```

---

## 실전 예제: 웹훅 기반 채널

외부 서비스에서 HTTP 웹훅(Webhook)을 받아 Claude Code로 전달하는 실전 채널 예제입니다.

### 의존성 설치

```bash
bun add express
bun add -d @types/express
```

### server.ts (웹훅 채널)

```typescript
import { stdin, stdout } from "process";
import express from "express";

// --- JSON-RPC 헬퍼 (앞의 템플릿과 동일) ---

function send(msg: Record<string, unknown>): void {
  const json = JSON.stringify({ jsonrpc: "2.0", ...msg });
  stdout.write(`Content-Length: ${Buffer.byteLength(json)}\r\n\r\n${json}`);
}

let idCounter = 0;
function nextId(): number {
  return ++idCounter;
}

// --- 웹훅 서버 ---

const PORT = parseInt(process.env.WEBHOOK_PORT || "3100", 10);
let isReady = false;

function startWebhookServer(): void {
  const app = express();
  app.use(express.json());

  // 웹훅 수신 엔드포인트
  app.post("/webhook", (req, res) => {
    const { chat_id, user, message } = req.body;

    if (!chat_id || !message) {
      res.status(400).json({ error: "chat_id와 message는 필수입니다" });
      return;
    }

    // Claude Code 세션으로 메시지를 푸시합니다
    send({
      method: "notifications/message",
      params: {
        level: "info",
        data: `<channel source="webhook" chat_id="${chat_id}" user="${user || "anonymous"}">${message}</channel>`,
      },
    });

    res.json({ status: "delivered" });
  });

  // 상태 확인 엔드포인트
  app.get("/health", (_req, res) => {
    res.json({ status: "ok", ready: isReady });
  });

  app.listen(PORT, () => {
    process.stderr.write(`[웹훅 채널] http://localhost:${PORT}/webhook 에서 대기 중\n`);
  });
}

// --- MCP 프로토콜 처리 ---

function handleRequest(id: number | string, method: string, params?: any): void {
  switch (method) {
    case "initialize":
      send({
        id,
        result: {
          protocolVersion: "2024-11-05",
          capabilities: {
            tools: {},
            experimental: { "claude/channel": {} },
          },
          serverInfo: { name: "webhook-channel", version: "0.0.1" },
        },
      });
      break;

    case "tools/list":
      send({
        id,
        result: {
          tools: [
            {
              name: "reply",
              description: "웹훅 채널을 통해 응답을 전송합니다",
              inputSchema: {
                type: "object",
                properties: {
                  chat_id: { type: "string", description: "대화 식별자" },
                  text: { type: "string", description: "응답 메시지" },
                },
                required: ["chat_id", "text"],
              },
            },
          ],
        },
      });
      break;

    case "tools/call":
      if (params?.name === "reply") {
        const { chat_id, text } = params.arguments;
        // 실제 구현에서는 콜백 URL로 HTTP 요청을 보냅니다
        process.stderr.write(`[응답 → ${chat_id}] ${text}\n`);
        send({
          id,
          result: { content: [{ type: "text", text: "응답 전송 완료" }] },
        });
      }
      break;

    default:
      send({ id, error: { code: -32601, message: `지원하지 않는 메서드: ${method}` } });
  }
}

function handleNotification(method: string): void {
  if (method === "initialized") {
    isReady = true;
    process.stderr.write("[웹훅 채널] MCP 초기화 완료\n");
    startWebhookServer();
  }
}

// --- stdin 파서 ---

let buffer = "";
stdin.setEncoding("utf-8");
stdin.on("data", (chunk: string) => {
  buffer += chunk;
  while (true) {
    const headerEnd = buffer.indexOf("\r\n\r\n");
    if (headerEnd === -1) break;
    const header = buffer.slice(0, headerEnd);
    const match = header.match(/Content-Length:\s*(\d+)/i);
    if (!match) { buffer = buffer.slice(headerEnd + 4); continue; }
    const len = parseInt(match[1], 10);
    const bodyStart = headerEnd + 4;
    if (buffer.length < bodyStart + len) break;
    const body = buffer.slice(bodyStart, bodyStart + len);
    buffer = buffer.slice(bodyStart + len);
    try {
      const msg = JSON.parse(body);
      if (msg.id !== undefined && msg.method) handleRequest(msg.id, msg.method, msg.params);
      else if (msg.method && msg.id === undefined) handleNotification(msg.method);
    } catch (e) {
      process.stderr.write(`[파싱 오류] ${e}\n`);
    }
  }
});
```

### 웹훅 테스트

채널 모드로 Claude Code를 실행한 상태에서, 다른 터미널에서 웹훅을 보내봅니다.

```bash
curl -X POST http://localhost:3100/webhook \
  -H "Content-Type: application/json" \
  -d '{"chat_id": "test-001", "user": "개발자", "message": "현재 디렉토리의 파일 목록을 알려줘"}'
```

---

## 트러블슈팅

| 문제 | 원인 | 해결 방법 |
|------|------|-----------|
| 채널이 인식되지 않음 | capability 선언 누락 | `initialize` 응답에 `experimental: { "claude/channel": {} }`가 포함되어 있는지 확인 |
| `--channels` 플래그 오류 | Claude Code 버전 미달 | `claude --version`으로 v2.1.80 이상인지 확인, 아니면 업데이트 |
| MCP 서버가 시작되지 않음 | `.mcp.json` 경로 오류 | `${CLAUDE_PLUGIN_ROOT}` 변수를 사용하고, `command`가 올바른 런타임(bun/node)을 가리키는지 확인 |
| 메시지가 Claude에게 전달되지 않음 | `notifications/message` 형식 오류 | `data` 필드에 `<channel source="..." chat_id="...">` XML 태그가 올바르게 포함되어 있는지 확인 |
| stdout에 디버그 출력을 보냄 | stdout/stderr 혼동 | stdout은 MCP 프로토콜 전용입니다. 디버그 로그는 반드시 `process.stderr.write()`를 사용하세요 |
| reply 도구가 호출되지 않음 | `tools/list`에 도구 미등록 | `tools/list` 응답에 reply 도구가 정의되어 있는지, `inputSchema`가 유효한 JSON Schema인지 확인 |
| `plugin install --local` 실패 | plugin.json 누락 또는 형식 오류 | 프로젝트 루트에 `plugin.json`이 있는지, JSON 형식이 올바른지 확인 |
| Team/Enterprise에서 채널 비활성 | channelsEnabled 미설정 | Admin에게 claude.ai > Admin settings > Claude Code > Channels 활성화 요청 |
| Content-Length 파싱 실패 | 헤더 형식 오류 | `Content-Length: {바이트수}\r\n\r\n` 형식을 정확히 따르고, 문자열 길이가 아닌 바이트 길이(`Buffer.byteLength`)를 사용 |
| 여러 채널 동시 실행 시 충돌 | 포트 또는 이름 중복 | 각 채널의 서버 이름(`serverInfo.name`)과 사용 포트가 고유한지 확인 |

---

## 다음 단계 / 참고 자료

이 가이드를 완료했다면, 아래 순서로 학습을 이어가는 것을 추천합니다.

### 학습 경로

1. **Discord 플러그인 분석하기** - 공식 Discord 플러그인의 소스코드를 읽으며 실제 프로덕션 수준의 채널 구현을 학습합니다.
   - 소스 위치: [claude-plugins-official/discord](https://github.com/anthropics/claude-plugins-official/tree/main/external_plugins/discord)
   - [Discord Integration 가이드](/pages/resources/discord-integration/)도 함께 참고하세요.

2. **도구(Tools) 확장하기** - `reply` 외에 `react`, `edit_message`, `fetch_history` 등 다양한 도구를 추가하여 채널의 기능을 풍부하게 만들어 보세요.

3. **접근 제어 구현하기** - 페어링 코드, allowlist 등 보안 메커니즘을 추가하여 승인된 사용자만 채널을 사용할 수 있도록 합니다.

4. **파일 첨부 지원하기** - reply 도구에 `files` 파라미터를 추가하여 Claude가 생성한 파일을 외부 서비스로 전송할 수 있도록 확장합니다.

### 참고 자료

| 자료 | 링크 |
|------|------|
| MCP 공식 스펙 | [modelcontextprotocol.io](https://modelcontextprotocol.io) |
| Claude Code 공식 문서 | [docs.anthropic.com/claude-code](https://docs.anthropic.com/en/docs/claude-code) |
| 공식 플러그인 저장소 | [github.com/anthropics/claude-plugins-official](https://github.com/anthropics/claude-plugins-official) |
| Discord 연동 가이드 | [Discord Integration](/pages/resources/discord-integration/) |
