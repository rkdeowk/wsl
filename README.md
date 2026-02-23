# Ubuntu Dev Container Python Workspace

CI 없이 로컬에서 품질 게이트를 실행하는 Python 개발 워크스페이스입니다.
공식 실행 방식은 `Ubuntu 호스트 + Dev Container`입니다.

## 초보자 5분 시작

1. Docker Engine이 동작하는지 확인

```bash
docker version
```

2. 저장소를 VS Code에서 열고 컨테이너로 재진입

```bash
code .
# Command Palette -> Dev Containers: Reopen in Container
```

3. 컨테이너 터미널에서 아래 한 명령 실행

```bash
make start
```

이 단계가 통과하면 기본 준비가 끝납니다.

## 실행 치트시트

- `make start`: 온보딩 바로 실행(`bootstrap` + `doctor`)
- `make bootstrap`: 처음 설정/재설치
- `make doctor`: 환경 진단
- `make fix`: 자동 수정 + 포맷
- `make verify`: 읽기 전용 검사(ruff/mypy/pytest)
- `make check`: `fix` + `verify`
- `make audit`: 의존성 취약점 점검
- `make reset`: 가상환경 캐시 삭제 후 재설치
- `make smoke`: setup/doctor/verify 통합 스모크

일상 루틴:

```bash
make fix
make verify
git add -A
git commit -m "your message"
git push
```

## 문제 해결

가장 먼저 아래 순서로 실행합니다.

```bash
make doctor
make reset
make doctor
```

`make start`를 다시 실행해도 동일한 진단 흐름을 한 번에 수행할 수 있습니다.

## 고급/예외 실행

기본 정책은 Dev Container 내부 실행입니다.
예외적으로 호스트 실행이 필요하면 `ALLOW_HOST_RUN=1`로 우회할 수 있습니다.

```bash
ALLOW_HOST_RUN=1 bash .devcontainer/setup.sh doctor --strict
```

setup 스크립트 직접 실행:

```bash
bash .devcontainer/setup.sh setup --strict
bash .devcontainer/setup.sh doctor --strict
bash .devcontainer/setup.sh verify --strict
```

온보딩을 분리 실행하고 싶다면 아래 두 명령을 순서대로 사용하세요.

```bash
make bootstrap
make doctor
```

지원 옵션:

- `--fast`: setup 검증 단계 생략
- `--strict`: 실패 시 즉시 종료
- `--autoupdate-hooks`: pre-commit autoupdate 실행
- `--editable`: `pip install -e .` 추가 실행

## 유지보수 시작점

어디를 수정해야 할지 빠르게 찾으려면 `docs/MAINTENANCE.md`를 먼저 확인하세요.

## WSL2 부록 (선택)

Windows 환경이면 아래를 추가로 준비합니다.

1. PowerShell(관리자)에서 `wsl --install -d Ubuntu` 실행
2. 이미 설치되어 있으면 `wsl --update` 실행
3. Docker Desktop에서 WSL2 엔진/통합 활성화
4. WSL 터미널에서 `code .` 후 Dev Container로 재진입
