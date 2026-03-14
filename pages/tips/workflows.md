---
layout: post
title: Workflow Tips
description: 효율적인 Claude Code 워크플로우
permalink: /pages/tips/workflows
---

## Git 워크플로우

```mermaid
graph LR
    A[코드 작성] --> B[/commit]
    B --> C[테스트 실행]
    C --> D{통과?}
    D -->|Yes| E[PR 생성]
    D -->|No| A
```

### 커밋 자동화
`/commit` 명령으로 변경사항을 분석하고 적절한 커밋 메시지를 생성합니다.

### PR 작성
Claude Code가 변경 내역을 분석하여 PR 제목과 본문을 자동 생성합니다.

## 코드 리뷰 워크플로우

1. PR URL을 Claude Code에 전달
2. 변경사항 분석 및 리뷰 코멘트 생성
3. 수정 사항 반영 후 재확인

## 디버깅 워크플로우

1. 에러 메시지를 Claude Code에 붙여넣기
2. 관련 파일을 자동 탐색
3. 근본 원인 분석 및 수정안 제시
4. 테스트로 수정 확인

## 병렬 작업

TeamCreate를 활용하여 독립적인 작업을 동시에 처리:
- 프론트엔드 + 백엔드 동시 수정
- 테스트 작성 + 문서 업데이트
- 여러 파일의 동일 패턴 리팩터링
