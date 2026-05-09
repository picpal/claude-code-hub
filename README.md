# Claude Code Hub

Claude Code 패치노트, 리소스, 팁을 한곳에서 모아보는 문서 사이트입니다.

**https://picpal.github.io/claude-code-hub**

## 구성

| 섹션 | 내용 |
|------|------|
| **Patch Notes** | Claude Code 릴리스 노트 (v2.1.68 ~ 최신) |
| **Resources** | 시작 가이드, MCP 서버, Hooks, Skills, Discord 연동, Claude Design 등 |
| **Tips & Tricks** | 생산성 팁, 워크플로우 가이드 |
| **Cheatsheet** | 명령어, 단축키, 설정 빠른 참조 |

## 기술 스택

- **Jekyll** (kramdown + GFM)
- **GitHub Pages** 배포 (`main` push → `jekyll.yml` 워크플로가 자동 빌드·배포)
- **jekyll-seo-tag** 플러그인
- **GitHub Actions** 로 패치노트 자동 동기화

## 로컬 실행

```bash
bundle install
bundle exec jekyll serve
```

`http://localhost:4000/claude-code-hub/` 에서 확인 가능합니다.

## 디렉토리 구조

```
pages/
  patch-notes/    # 버전별 릴리스 노트 (자동 생성 — 수동 편집 금지)
  resources/      # 가이드 문서
  tips/           # 팁 & 트릭
  cheatsheet/     # 빠른 참조
_data/
  navigation.yml  # 사이드바 메뉴 구성
_layouts/         # 페이지 레이아웃 템플릿
_includes/        # 헤더·사이드바 등 공통 조각
_sass/            # 스타일 파티얼
assets/           # CSS·JS 등 정적 자원
scripts/
  sync-patch-notes.sh       # 릴리스 → 마크다운 변환
  test-sync-patch-notes.sh  # 위 스크립트 테스트
.github/workflows/
  jekyll.yml            # 빌드·배포
  sync-patch-notes.yml  # 패치노트 정기 동기화
docs/             # 설계 스펙·구현 계획
```

## 패치노트 자동 동기화

`pages/patch-notes/` 는 손으로 채우지 않는다. `sync-patch-notes.yml` 워크플로가 매시간
(`cron: '10 * * * *'`) `anthropics/claude-code` 릴리스를 확인해서, 새 릴리스가 있으면
`scripts/sync-patch-notes.sh` 로 마크다운을 만들고 커밋·푸시한 뒤 배포 워크플로를 호출한다.

- 새 릴리스가 없으면 sync 잡 자체를 건너뛴다
- body 가 빈 릴리스는 파일을 만들지 않는다
- 즉시 돌리고 싶으면 Actions 탭에서 **Sync Patch Notes** 를 수동 실행 (`workflow_dispatch`)
- 전체를 다시 만들려면 로컬에서 `bash scripts/sync-patch-notes.sh --force`
- 스크립트를 고쳤다면 `bash scripts/test-sync-patch-notes.sh` 로 검증

이 디렉토리를 수동으로 편집하면 다음 동기화 때 스크립트 출력과 어긋난다.

## 페이지 추가 방법

패치노트를 제외한 나머지 카테고리(`resources`, `tips`, `cheatsheet`)에 해당한다.

1. `pages/<카테고리>/` 에 마크다운 파일 생성
2. frontmatter 작성:
   ```yaml
   ---
   layout: post
   title: "페이지 제목"
   description: "설명"
   permalink: /pages/<카테고리>/<슬러그>/
   ---
   ```
3. `_data/navigation.yml` 에 메뉴 항목 추가
