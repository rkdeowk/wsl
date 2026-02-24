# 변경 이력

이 문서는 프로젝트의 주요 변경 사항을 기록합니다.

형식은 [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)를 참고하며,
버전은 [Semantic Versioning](https://semver.org/spec/v2.0.0.html)을 따릅니다.

## [Unreleased]

### 추가
- 초보자용 유지보수 맵 문서 `docs/MAINTENANCE.md` 추가.

### 변경
- setup 스크립트 내부 구조를 역할별 섹션으로 재정렬해 가독성 개선(동작 호환 유지).
- `tasks` 디스패치를 `case` 기반으로 단순화해 수정 진입장벽 완화.
- README를 명령 중심 치트시트 형태로 재구성하고 고급/예외 실행 섹션 분리.
- Makefile/스크립트의 중복 실행 패턴과 저가치 래퍼 함수를 정리해 구조 단순화(공개 명령/옵션 호환 유지).

### 수정
- 오류 메시지를 원인 + 즉시 실행 가능한 명령 형태로 통일.

## [0.1.0] - 2026-02-18

### 추가
- Dev Container 기반 Python 개발 워크스페이스 초기 구성.
- `make bootstrap`, `make doctor`, `make verify` 및 git hook 기반 로컬 품질 게이트 구성.
- setup 흐름 및 핵심 회귀 시나리오 점검용 smoke 테스트 추가.
