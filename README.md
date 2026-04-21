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
- **GitHub Pages** 배포
- **jekyll-seo-tag** 플러그인

## 로컬 실행

```bash
bundle install
bundle exec jekyll serve
```

`http://localhost:4000/claude-code-hub/` 에서 확인 가능합니다.

## 디렉토리 구조

```
pages/
  patch-notes/    # 버전별 릴리스 노트
  resources/      # 가이드 문서
  tips/           # 팁 & 트릭
  cheatsheet/     # 빠른 참조
_data/
  navigation.yml  # 사이드바 메뉴 구성
_layouts/         # 페이지 레이아웃 템플릿
```

## 페이지 추가 방법

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
