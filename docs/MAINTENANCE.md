# Maintenance Map

초보 개발자가 빠르게 수정 지점을 찾고, 동일한 검증 순서로 안전하게 반영하기 위한 문서입니다.

## 어디를 수정할지 찾기

| 증상/요청 | 우선 수정 파일 | 이유 |
| --- | --- | --- |
| 옵션 파싱/도움말 문구 변경 | `.devcontainer/lib/core.sh` | CLI 인자 처리와 오류/도움말이 모여 있음 |
| `setup/doctor/verify` 실행 분기 변경 | `.devcontainer/lib/tasks.sh` | 모드 디스패치와 각 task 진입점이 모여 있음 |
| Dev Container 정책, Python/venv, git hook, 검사 로직 변경 | `.devcontainer/lib/workflows.sh` | 실제 작업 흐름 함수가 모여 있음 |
| 기본 경로/기본값/필수 파일 목록 변경 | `.devcontainer/lib/config.sh` | 상수/환경 변수 기본값만 선언 |
| 팀원이 자주 쓰는 명령 안내 변경 | `README.md` | 사용자 온보딩 문서 |
| 커맨드 이름/도움말 문구 변경 | `Makefile` | 개발자 실행 진입점 |

## 수정 후 검증 순서 (고정)

아래 순서를 그대로 실행합니다.

```bash
make smoke
make start
make verify
```

선택 검증(쉘 문법 확인):

```bash
bash -n .devcontainer/setup.sh .devcontainer/lib/*.sh .devcontainer/tests/smoke.sh
```

## 초보자용 변경 원칙

- 한 함수는 한 책임만 갖게 유지합니다.
- 로그 포맷은 `[INFO]`, `[WARNING]`, `[ERROR]`로 통일합니다.
- 기존 명령과 옵션 이름은 바꾸지 않습니다(호환성 우선).
- 새 명령은 기존 흐름을 감싼 별칭 형태(`start = bootstrap + doctor`)로 추가합니다.
- 오류 메시지는 원인과 바로 실행할 명령을 함께 적습니다.
- 문서는 명령 중심으로 쓰고, 긴 설명은 뒤로 보냅니다.
