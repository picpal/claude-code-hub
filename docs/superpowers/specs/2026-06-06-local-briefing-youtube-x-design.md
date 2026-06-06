# 로컬 통합 브리핑 (briefing v2) — YouTube + X 섹션 추가

- 작성일: 2026-06-06
- 상태: 설계 확정 대기 (사용자 리뷰 전)
- 대상 프로젝트: `claude-code-hub`

## 1. 개요 / 목표

기존 Claude Ecosystem Briefing에 **YouTube(유명 LLM 인물 신규 영상)** 와 **X(주목 게시글)** 두 섹션을 추가한다.
X는 로그인 세션이 필요해 클라우드(GitHub Actions)에서 수집할 수 없으므로, 브리핑 전체를 **로컬 PC 실행**으로 전환하고
**하루 2회(09:00 / 15:00 KST)** 직전 실행 이후의 신규 항목만 모아 한 건의 Slack 메시지로 발송한다.

성공 기준:
- 09:00·15:00에 신규 항목이 있으면 YouTube·X 섹션을 포함한 단일 Slack 브리핑이 발송된다.
- 각 항목은 **핵심 한 줄 + 출처 링크** 형태로 가독성 있게 표시된다.
- 신규 항목이 없으면 발송하지 않는다(노이즈 방지).
- 한 소스가 실패해도 나머지 소스는 정상 발송된다.

## 2. 배경 & 제약

현 상태:
- `scripts/claude-briefing.sh`가 GitHub Actions cron(`0 4,9,13 * * *` UTC)으로 4개 무인증 소스(Anthropic 블로그, Claude 블로그, HN Algolia, GitHub 릴리스)를 수집 → dedup(`.briefing-state/seen-urls.txt`) → Claude Haiku 요약 → Slack webhook 발송.
- `sync-patch-notes.yml`이 신규 릴리스 감지 시 패치노트 동기화 후 briefing 워크플로우를 트리거.
- 시크릿: `ANTHROPIC_API_KEY`, `GITHUB_TOKEN`, `SLACK_WEBHOOK_URL` (모두 GitHub Secrets).

제약/철학:
- 기존 수집은 전부 무료·무인증 curl + grep/jq. "유료 키를 쓰지 않는다"가 암묵 철학.
- X는 2023년 이후 무료·안정 검색 API가 없음 → 로그인 세션 쿠키 기반 수집이 유일한 무료 경로.

## 3. 확정된 결정

| 항목 | 결정 |
|---|---|
| 실행 위치 | 전부 로컬 PC (단일 오케스트레이터) |
| 발송 시각 | 09:00 / 15:00 KST 2회, 매회 직전 이후 신규(delta)만 |
| 클라우드 | `claude-briefing.yml` cron 비활성화, `sync-patch-notes.yml`의 briefing 트리거 스텝 제거 (패치노트 동기화 자체는 유지) |
| 인물 리스트 | 스타터 리스트 시드 + config 파일 분리(사용자 편집 가능) |
| YouTube 깊이 | 가볍게 — 제목 + 설명 메타만 요약 (자막 추출 안 함) |
| X 수집 방식 | **C안**: 브라우저 로그인 세션 쿠키(`auth_token`+`ct0`) + X 내부 API 직접 호출 (라이브러리 없이 curl/python). 폴백: gstack `browse` DOM 스크랩(B안) |

## 4. 아키텍처

```
launchd (09:00 / 15:00 KST)
   └─ scripts/local-briefing.sh   (오케스트레이터)
        ├─ 무인증 수집 (기존 로직 재사용): Anthropic/Claude 블로그, HN, GitHub 릴리스
        ├─ collect-youtube.sh : creators 채널 RSS → 신규 영상
        ├─ collect-x.py       : creators X 계정 → 신규 게시글 (쿠키 인증, 내부 API)
        │
        ├─ 병합 + dedup (.briefing-state/seen-urls.txt 재사용)
        ├─ 카테고리 태깅 → Haiku 요약 (고정 섹션 스펙)
        └─ Slack webhook 1건 발송
```

설계 원칙(격리·명확한 경계):
- 각 collector는 독립 실행 가능한 모듈. 공통 출력 계약(§6)으로만 통신.
- 오케스트레이터는 수집 방식의 내부를 모른 채 표준 항목 라인을 받아 dedup·요약·발송만 담당.
- 한 collector가 비정상 종료해도 오케스트레이터는 나머지 결과로 계속 진행(기존 "fetch failed, skipping" 패턴 유지).

## 5. 구성요소

### 5.1 `config/creators.tsv`
추적 대상 인물 목록. 탭 구분(파싱에 yq 등 추가 의존성 불필요).

형식:
```
# name <TAB> youtube_channel_id <TAB> x_handle   (없는 칸은 비움)
Andrej Karpathy	<UC...>	karpathy
Yannic Kilcher	<UC...>	ykilcher
Two Minute Papers	<UC...>	twominutepapers
AI Explained	<UC...>	AIExplainedYT
Matt Wolfe	<UC...>	mreflow
Andrew Ng	<UC...>	AndrewYNg
3Blue1Brown	<UC...>	3blue1brown
Jim Fan		DrJimFan
swyx		swyx
Simon Willison		simonw
Sam Altman		sama
Greg Brockman		gdb
Demis Hassabis		demishassabis
```
- `youtube_channel_id`(UC...)는 구현 첫 단계의 `scripts/resolve-channel-ids.sh` 헬퍼로 1회 채운다(핸들 페이지에서 `"channelId":"UC..."` 추출). 채널이 없거나 X 전용 인물은 해당 칸을 비운다.
- 사용자가 언제든 행을 추가/삭제하여 추적 대상을 바꾼다.

### 5.2 `scripts/collect-youtube.sh`
- 각 `youtube_channel_id`에 대해 `https://www.youtube.com/feeds/videos.xml?channel_id=<UC...>` 조회(로그인 불필요).
- `<entry>`에서 video id, 제목, `published`, `media:description` 추출.
- 필터: `published`가 최근 24h 이내 **그리고** 미열람(`seen-urls.txt`).
- 출력: 카테고리 `youtube`, source=채널명, title=영상 제목, url=영상 링크, meta=설명 앞부분(요약용).
- 깊이는 "가볍게": 자막 추출 없음. 제목+설명만.

### 5.3 `scripts/collect-x.py` (C안)
- **쿠키 소스**: `~/.briefing/x_cookies.txt`(gitignore)에 1회 추출해 둔 `auth_token`, `ct0`. 자동 실행 중 Chrome이 켜져 있어 라이브 추출이 실패하는 문제를 피하기 위해 파일 방식 사용. 만료/로그아웃 시에만 재추출.
- **호출**: X 내부 엔드포인트를 직접 호출(라이브러리 없이 `requests`/`curl`).
  - 핸들 → user id 해석(`UserByScreenName` 류) → 사용자 타임라인(`UserTweets` 류) 조회.
  - 헤더: `authorization: Bearer <web bearer>`, `x-csrf-token: <ct0>`, `cookie: auth_token=…; ct0=…`, `x-twitter-active-user: yes`, `x-twitter-auth-type: OAuth2Session`.
- 필터: 원본 게시글만(리트윗/리플/프로모션 제외), 최근 24h, 미열람.
- 출력: 카테고리 `x`, source=`@handle`, title=본문 앞부분, url=게시글 permalink, meta=본문 전문(요약용).
- **폴백(B안)**: 내부 API 차단/스키마 변경 시 gstack `browse` + 쿠키로 프로필 DOM 스크랩으로 전환(별도 함수로 격리, 동일 출력 계약).
- 비공식 엔드포인트라 정확한 endpoint/queryId/web bearer 값은 §11 spike에서 실제 세션 트래픽을 캡처해 확정한다.

### 5.4 `scripts/local-briefing.sh` (오케스트레이터)
- 기존 `claude-briefing.sh`의 무인증 수집 로직을 재사용/이관.
- `collect-youtube.sh`, `collect-x.py`를 호출해 표준 항목 라인을 수집.
- dedup(`is_seen`/`mark_seen`), 카테고리 태깅, Haiku 요약, Slack 발송, 상태 트림(기존 1000줄 룰) 수행.
- 발송 시각대(09/15)를 헤더에 표기.

### 5.5 스케줄러 `~/Library/LaunchAgents/com.claudehub.briefing.plist`
- `StartCalendarInterval` 09:00, 15:00 두 항목.
- 작업 디렉토리=레포 경로, stdout/stderr는 로컬 로그 파일로.
- PC 절전/종료로 정시를 놓치면 다음 기상 시 1회 실행되도록 설정(정확 백필은 아님, §11 리스크).

### 5.6 로컬 시크릿 `.env` (gitignore)
- `ANTHROPIC_API_KEY`, `SLACK_WEBHOOK_URL`을 로컬 `.env`로 보관, 오케스트레이터가 source.
- GitHub Secrets는 클라우드 비활성화로 더 이상 브리핑에 쓰이지 않음(패치노트 동기화용 토큰만 잔존).

### 5.7 클라우드 변경
- `.github/workflows/claude-briefing.yml`: `schedule:` 트리거 제거(또는 주석), `workflow_dispatch`만 남겨 수동 디버그용 유지.
- `.github/workflows/sync-patch-notes.yml`: "Trigger briefing" 스텝 제거. 패치노트 sync/deploy는 유지.

## 6. 데이터 계약 (collector → 오케스트레이터)

각 collector는 항목당 한 줄을 emit(탭 구분):
```
category <TAB> source <TAB> title <TAB> url <TAB> meta
```
- `category` ∈ { `news`, `tech`, `community`, `youtube`, `x` }
- `url`은 dedup 키.
- `meta`는 Haiku 요약 입력용 부가 텍스트(설명/본문 등). 줄바꿈은 공백 치환.

## 7. Slack 출력 포맷

Haiku 시스템 프롬프트를 확장해 카테고리별 고정 섹션을 렌더(항목 없으면 섹션 생략):

```
🤖 Claude Ecosystem Briefing  (09:00)

📰 오늘의 핵심
🔧 기술 업데이트
🌐 커뮤니티 동향
🎥 YouTube — 유명 인물 신규 영상
   • <제목> — 한 줄 핵심  <url|채널명>
🐦 X — 주목 게시글
   • <한 줄 핵심>  <url|@핸들>
💡 인사이트
📊 새 소식 N건

🔗 사이트: <https://picpal.github.io/claude-code-hub|Claude Code Hub>
```
- 한국어, Slack mrkdwn(`*bold*`, `<url|title>`), 300단어 내외 유지(기존 규칙 계승).
- YouTube/X 항목은 반드시 핵심 한 줄 + 출처 링크를 함께 표기.

## 8. 상태 / dedup

- 기존 `.briefing-state/seen-urls.txt` 재사용 → 과거 본 항목 재알림 방지(YouTube/X URL, 릴리스 태그 포함).
- 로컬 전용 실행이므로 상태 자동 커밋은 하지 않음(클라우드 동기화 불필요).
- 최초 실행 시드(`.seeded`) 가드 유지 — 첫 로컬 실행은 알림 없이 상태만 시드.
- 1000줄 초과 시 800줄로 트림(기존 룰).

## 9. 에러 처리 & 폴백

- 각 collector는 독립적으로 try/skip: 실패 시 해당 소스만 건너뛰고 로그.
- X 쿠키 만료/401 → X 섹션만 스킵 + "X 쿠키 재추출 필요" 경고를 로그(및 선택적으로 Slack 푸터에 1줄).
- X 내부 API 차단/스키마 변경 → B안(browse DOM) 폴백 함수로 전환.
- Haiku 실패 → 원본 항목 그대로 폴백 출력(기존 동작).
- 신규 0건 → 발송 안 함.

## 10. 보안

- `~/.briefing/x_cookies.txt`, `.env`는 반드시 gitignore. 레포에 커밋 금지.
- 쿠키는 세션 탈취에 해당하는 민감 정보 → 파일 권한 600 권장, 로그에 값 미출력.
- API 키가 클라우드 시크릿에서 로컬 디스크로 이동하므로 gitignore 확인을 체크리스트에 포함.

## 11. 테스트 전략

- `DRY_RUN=1`: Slack 대신 stdout 출력(기존 패턴 계승).
- collector 단독 실행 테스트: 각 스크립트를 직접 돌려 표준 항목 라인 형식 검증.
- YouTube: 알려진 채널 1개로 최근 영상 파싱 확인.
- X: **구현 첫 단계 spike** — 단일 계정으로 쿠키 인증 + 내부 API 호출이 실제 동작하는지 검증(endpoint/queryId/bearer 확정). 실패 시 즉시 B안 폴백 검증.
- 24h 윈도우 + dedup 경계 테스트(같은 항목 두 번 안 나오는지).
- 첫 실행 시드 동작 확인(알림 없이 상태만 채워지는지).

## 12. 리스크 & 완화

| 리스크 | 영향 | 완화 |
|---|---|---|
| X 내부 API/쿠키 취약성 | X 섹션 누락 | spike로 조기 검증, 401 시 graceful skip + 재추출 안내, B안 폴백 |
| PC 꺼짐/절전 | 정시 발송 누락 | launchd 기상 시 1회 실행; 완전 보장은 아님(수용) |
| 로컬 시크릿 유출 | 키/세션 노출 | gitignore + 파일 권한 + 로그 마스킹 |
| YouTube channel_id 미해석 | 채널 누락 | resolve 헬퍼로 1회 일괄 해석, 빈 칸은 스킵 |
| Chrome 실행 중 쿠키 잠금 | 자동 추출 실패 | 라이브 추출 대신 파일 추출 방식 채택 |

## 13. 범위 밖 (YAGNI)

- YouTube 자막 깊이 추출(가벼운 메타 요약으로 확정).
- 키워드 검색 기반 수집(계정 기반으로 확정).
- 클라우드 always-on(로컬 실행으로 확정).
- DB/큐(평면 파일 상태 유지).
- 알림 채널 다변화(Slack 단일 유지).

## 14. 오픈 이슈 (구현 중 확정)

1. X 내부 엔드포인트 정확한 경로/queryId/web bearer — spike에서 캡처. ✅ 해결(§15).
2. 쿠키 추출 1회 절차의 구체 수단(수동 복사 vs 헬퍼 스크립트) — spike 결과에 따라 결정. ✅ 해결(§15).
3. launchd 누락 실행 처리 정책의 세부(기상 시 즉시 vs 다음 정시) — 구현 시 결정.

## 15. 구현 변경사항 (Implementation deltas, 2026-06-07)

설계 후 구현 중 확정/변경된 사항. 본문(§5.3, §5.6 등)보다 이 절이 우선한다.

- **X 쿠키: 파일 → 런타임 브라우저 읽기.** §5.3의 "파일 1회 추출" 대신, 사용자 선택으로 youtube-study-notes와 동일하게 **`collect_x.py`가 실행 시 `browser_cookie3`로 로그인된 Chrome 세션에서 `auth_token`/`ct0`를 직접 읽어 in-flight로만 사용**(절대 파일로 덤프·로그하지 않음). `~/.briefing/x_cookies.txt`는 폴백으로 유지(`_cookies_from_file`).
- **Python 실행환경: 시스템 → 레포 venv.** `browser_cookie3` 의존성 + launchd 무인 실행 견고성을 위해 레포 `.venv`(requests + browser_cookie3) 사용. 오케스트레이터·plist는 **절대경로 `.venv/bin/python`** 호출. 테스트는 시스템 pytest 유지(`browser_cookie3`는 지연 import라 영향 없음). `.venv/`는 gitignore.
- **X 엔드포인트.** `scripts/x_endpoints.json`에 실 query_id + features + field_toggles 저장(캡처 기반). 파서는 응답이 `timeline_v2` 또는 `timeline`, screen_name이 `core` 또는 `legacy` 어느 쪽이든, 모듈(`TimelineTimelineModule`) 엔트리까지 처리하도록 보강.
- **X 실패 가시화.** `collect_x.py`는 쿠키/엔드포인트 부재 또는 전 핸들 실패 시 **exit 2** 반환 → 오케스트레이터가 브리핑에 `⚠️ X 수집 실패` 한 줄을 노출(stderr만이 아님). query_id는 수개월마다 회전하므로 갱신 신호로 활용.
- **launchctl은 사용자 실행.** 프로젝트 보안 훅이 자격증명/X 식별자 추출 및 LaunchAgent 조작 bash 명령을 차단하므로, 쿠키 추출·query_id 추출·`launchctl load/kickstart`는 어시스턴트가 직접 실행하지 못하고 **사용자가 수행**한다. plist 파일은 `~/Library/LaunchAgents/`에 생성되어 있고 로드만 사용자 몫.
- **남은 사용자 작업.** (1) `.env` 생성(키 입력), (2) `launchctl load -w ~/Library/LaunchAgents/com.claudehub.briefing.plist`, (3) `launchctl kickstart -k gui/$(id -u)/com.claudehub.briefing` 1회 후 `.briefing-state/launchd.out.log`에서 X 라인 유무로 **launchd 컨텍스트 Keychain 접근 검증**(실패 시 쿠키 파일 폴백 사용).
