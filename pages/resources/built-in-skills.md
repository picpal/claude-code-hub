---
layout: post
title: Built-in Skills & Commands
description: Claude Code 공식 내장 슬래시 명령어 및 스킬 전체 목록
permalink: /pages/resources/built-in-skills/
---

## 목차
- [개요](#개요)
- [Built-in 명령어](#built-in-명령어)
- [Bundled Skills](#bundled-skills)
- [제거된 명령어](#제거된-명령어)
- [참고 자료](#참고-자료)

---

## 개요

Claude Code에는 CLI에 직접 내장된 **Built-in 명령어**와, 프롬프트 기반으로 동작하는 **Bundled Skills** 두 종류가 있습니다.

- **Built-in 명령어**: CLI 바이너리에 코딩된 핵심 기능. 설정, 세션 관리, 모델 제어, 외부 서비스 통합 등
- **Bundled Skills**: 자동 트리거 가능한 고급 자동화 스킬. 코드 리뷰, 배치 처리, 스케줄링 등

모든 명령어는 프롬프트 입력창에서 `/` 접두사로 호출합니다. `/skills` 명령어로 현재 사용 가능한 스킬 목록을 확인할 수 있습니다.

---

## Built-in 명령어

### 세션 관리

| 명령어 | 설명 | 사용 예시 |
|--------|------|-----------|
| `/help` | 도움말 및 사용 가능한 명령어 표시 | 명령어 목록 확인 |
| `/clear` | 컨텍스트를 비우고 새 대화 시작 | 대화 초기화 |
| `/exit` `/quit` | CLI 종료 | 세션 종료 |
| `/resume` `/continue` | 이전 대화 복구 또는 세션 선택기 열기 | `이전 작업 이어서 진행` |
| `/rename [name]` | 현재 세션 이름 변경 | `/rename auth-refactor` |
| `/branch` `/fork` | 현재 지점에서 대화 분기 생성 | 대체 경로 탐색 |
| `/compact [instructions]` | 대화 컴팩팅 (선택 지침 사용 가능) | 컨텍스트 유지하며 정리 |
| `/rewind` `/undo` | 이전 지점으로 대화 및 코드 복구 | 체크포인트 시스템 사용 |
| `/copy [N]` | 마지막 응답을 클립보드로 복사 | `/copy 2` (2번째 이전) |
| `/export [filename]` | 현재 대화를 텍스트로 내보내기 | 대화 기록 저장 |
| `/diff` | 미커밋 변경사항 및 각 턴 diff 보기 | 변경사항 검토 |
| `/recap` | 현재 세션의 한 줄 요약 생성 | 세션 정리 |
| `/btw <question>` | 빠른 옆질문 (대화에 추가 안 함) | 관련 없는 질문 |

### 모델 및 설정

| 명령어 | 설명 | 사용 예시 |
|--------|------|-----------|
| `/config` `/settings` | 테마, 모델, 출력 스타일 등 설정 조정 | 사용자 환경 설정 |
| `/model [model]` | AI 모델 선택 또는 변경 | `/model opus` |
| `/effort [level]` | 모델 effort level 조정 (low/medium/high/max) | `/effort high` |
| `/fast [on\|off]` | fast mode 토글 (동일 모델, 빠른 출력) | 빠른 응답 모드 |
| `/theme` | 색 테마 변경 (auto, dark, light 등) | `/theme dark` |
| `/color [color]` | 프롬프트 바 색상 설정 | `/color blue` |
| `/tui [mode]` | 터미널 UI 렌더러 설정 | `/tui fullscreen` |
| `/focus` | Focus view 전환 (마지막 프롬프트만 표시) | 축약된 뷰 |

### 계정 및 사용량

| 명령어 | 설명 | 사용 예시 |
|--------|------|-----------|
| `/login` | Anthropic 계정으로 로그인 | 계정 인증 |
| `/logout` | 계정 로그아웃 | 로그아웃 |
| `/status` | 버전, 모델, 계정, 연결 상태 표시 | 현재 상태 확인 |
| `/cost` | 토큰 사용량 통계 표시 | 사용 비용 확인 |
| `/usage` | 요금제 사용량 및 rate limit 상태 | 할당량 확인 |
| `/stats` | 일일 사용량, 세션 이력, 스트릭 시각화 | 사용 통계 |
| `/insights` | Claude Code 세션 분석 리포트 생성 | 사용 패턴 분석 |
| `/extra-usage` | rate limit 초과 시 extra usage 구성 | 추가 사용량 설정 |
| `/upgrade` | 상위 요금제로 업그레이드 | 계정 업그레이드 |
| `/passes` | 무료 주간 패스 공유 | 초대 코드 생성 |

### 프로젝트 및 권한

| 명령어 | 설명 | 사용 예시 |
|--------|------|-----------|
| `/init` | 프로젝트를 CLAUDE.md 가이드로 초기화 | 프로젝트 설정 시작 |
| `/plan [description]` | plan mode 직접 진입 | `/plan fix the auth bug` |
| `/permissions` | 도구 권한 규칙 (allow/ask/deny) 관리 | 권한 설정 |
| `/memory` | CLAUDE.md 메모리 파일 편집 | 장기 메모리 설정 |
| `/add-dir <path>` | 작업 디렉토리 추가 | `/add-dir /path/to/dir` |
| `/context` | 컨텍스트 사용량을 색상 그리드로 시각화 | 컨텍스트 최적화 |
| `/hooks` | 도구 이벤트에 대한 hook 설정 보기 | hook 구성 확인 |

### 확장 및 통합

| 명령어 | 설명 | 사용 예시 |
|--------|------|-----------|
| `/mcp` | MCP 서버 연결 관리 및 OAuth 인증 | MCP 설정 |
| `/agents` | agent 구성 관리 | 서브에이전트 설정 |
| `/plugin` | Claude Code 플러그인 관리 | 플러그인 활성화/비활성화 |
| `/reload-plugins` | 활성 플러그인 재로드 | 플러그인 변경 적용 |
| `/skills` | 사용 가능한 스킬 나열 | 스킬 탐색 |
| `/ide` | IDE 통합 관리 및 상태 표시 | VS Code 연동 |
| `/keybindings` | 키바인딩 설정 파일 열기 | 단축키 커스터마이징 |
| `/tasks` `/bashes` | 백그라운드 작업 나열 및 관리 | 실행 중인 bash 확인 |

### 외부 서비스 연결

| 명령어 | 설명 | 사용 예시 |
|--------|------|-----------|
| `/desktop` `/app` | Desktop 앱에서 세션 계속 | 데스크톱 앱 동기화 |
| `/remote-control` `/rc` | 세션을 claude.ai에서 원격 제어 | 웹에서 원격 제어 |
| `/teleport` `/tp` | 웹 세션을 터미널로 가져오기 | 웹 <-> 터미널 동기화 |
| `/web-setup` | GitHub 계정을 웹에 연결 | 웹 세션 설정 |
| `/remote-env` | 웹 세션의 원격 환경 구성 | 웹 환경 설정 |
| `/chrome` | Chrome의 Claude 설정 구성 | 브라우저 통합 |
| `/mobile` `/ios` `/android` | 모바일 앱 다운로드 QR 코드 표시 | 모바일 설정 |
| `/install-github-app` | Claude GitHub Actions 앱 설정 | GitHub 연동 |
| `/install-slack-app` | Claude Slack 앱 설치 | Slack 연동 |
| `/setup-bedrock` | Amazon Bedrock 인증/모델 설정 | AWS Bedrock 구성 |
| `/setup-vertex` | Google Vertex AI 인증/프로젝트 설정 | Google Cloud 구성 |

### 유틸리티

| 명령어 | 설명 | 사용 예시 |
|--------|------|-----------|
| `/doctor` | 설치 및 설정 진단 (f 키로 자동 수정) | 설정 검증 |
| `/terminal-setup` | 터미널 키바인딩 설정 (Shift+Enter 등) | 터미널 단축키 구성 |
| `/statusline` | Claude Code status line 구성 | 상태 표시줄 설정 |
| `/powerup` | 애니메이션 데모와 함께 기능 학습 | 기능 튜토리얼 |
| `/release-notes` | 대화형 버전 선택기로 changelog 보기 | 업데이트 내역 확인 |
| `/heapdump` | 메모리 분석을 위해 힙 스냅샷 생성 | 고메모리 사용 진단 |
| `/voice` | push-to-talk 음성 받아쓰기 토글 | 음성 입력 |
| `/privacy-settings` | 개인정보 보호 설정 (Pro/Max만) | 데이터 프라이버시 |
| `/stickers` | Claude Code 스티커 주문 | 머천다이즈 |

---

## Bundled Skills

Built-in과 달리 프롬프트 기반으로 동작하며, 코드 패턴 감지 시 자동 트리거될 수 있습니다.

| 스킬 | 설명 | 사용 예시 |
|------|------|-----------|
| `/review [PR]` | 로컬에서 pull request 코드 리뷰 | PR 리뷰 수행 |
| `/security-review` | 현재 브랜치 변경사항의 보안 취약점 분석 | 보안 감사 |
| `/simplify [focus]` | 변경 코드의 품질/효율성 검토 및 자동 수정 | 코드 정리 |
| `/batch <instruction>` | 대규모 변경을 병렬 worktree로 자동 처리 (5~30개) | `/batch migrate src/ from Solid to React` |
| `/loop [interval] [prompt]` | 프롬프트를 반복 실행 또는 auto-paced | `/loop 5m check if deploy finished` |
| `/schedule [description]` | 원격 에이전트 cron 스케줄링 | 정기 작업 설정 |
| `/claude-api` | Claude API 레퍼런스 자동 로드 (Python, TS, Java, Go) | API 앱 개발 |
| `/debug [description]` | 세션 debug logging 활성화 및 issue 분석 | 문제 디버깅 |
| `/less-permission-prompts` | 기존 호출 스캔 후 읽기 전용 호출 allowlist 추가 | 권한 프롬프트 감소 |
| `/autofix-pr [prompt]` | 웹 세션이 PR 감시하며 CI 실패/리뷰에 자동 수정 | PR 자동 수정 |
| `/ultraplan <prompt>` | ultraplan 세션 — 계획 초안, 브라우저 검토, 원격 실행 | 고급 계획 수립 |
| `/ultrareview [PR]` | 클라우드 샌드박스에서 다중에이전트 코드 리뷰 | 상세 리뷰 (3회 무료) |
| `/team-onboarding` | 지난 30일 사용 이력에서 팀 온보딩 가이드 생성 | 팀 설정 가이드 |

---

## 제거된 명령어

| 명령어 | 제거 버전 | 대체 방법 |
|--------|-----------|-----------|
| `/vim` | v2.1.92 | `/config` > Editor mode에서 Vim 토글 |
| `/pr-comments [PR]` | v2.1.91 | Claude에 직접 PR 의견 보도록 요청 |

---

## 참고 자료

- [공식 문서: CLI Usage](https://docs.anthropic.com/en/docs/claude-code/cli-usage)
- [공식 문서: Skills](https://code.claude.com/docs/en/skills)
