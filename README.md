# WSL Python Workspace

CI 없이 로컬에서 품질 게이트를 실행하는 Python 개발 워크스페이스입니다.

## 사전 준비

- VS Code + Dev Containers 확장
- Docker Desktop(또는 호환 컨테이너 런타임)
- 저장소를 Dev Container로 열기

## 처음 시작

```bash
make bootstrap
make doctor
```

- `make bootstrap`: 의존성 설치(`requirements.txt`), git hook 설치, 기본 검증까지 한 번에 수행합니다.
- `make doctor`: 필수 파일, `.venv`, 필수 개발 도구(pre-commit/ruff/mypy/pytest/pip-audit), git hook 상태를 진단합니다.

## 일상 작업 루틴

```bash
make fix
make verify
git add -A
git commit -m "your message"
git push
```

- `make fix`: `ruff check --fix` + `ruff format`
- `make verify`: 읽기 전용 검사(ruff/mypy/pytest)
- `git push` 시 pre-push hook에서 `make verify`가 다시 실행됩니다.

## 문제 해결

```bash
make doctor
make reset
make doctor
```

- `make reset`: `.venv`, `.mypy_cache`, `.pytest_cache`, `.ruff_cache`를 삭제 후 `make bootstrap`을 다시 실행합니다.

## 자주 쓰는 명령

- `make bootstrap`: 온보딩/재설치
- `make doctor`: 환경 진단
- `make reset`: 환경 초기화 + 재설치
- `make fix`: 자동 수정 + 포맷
- `make verify`: 읽기 전용 검사
- `make check`: `fix` + `verify`
- `make audit`: `pip-audit` 취약점 점검
- `make smoke`: setup/doctor/verify 통합 스모크 + 핵심 회귀 시나리오 검사

## setup 스크립트 직접 실행

```bash
bash .devcontainer/setup.sh setup --strict
bash .devcontainer/setup.sh doctor --strict
bash .devcontainer/setup.sh verify --strict
```

지원 옵션:

- `--fast`: setup 검증 단계 생략
- `--strict`: 실패 시 즉시 종료
- `--autoupdate-hooks`: pre-commit autoupdate 실행
- `--editable`: `pip install -e .` 추가 실행

## 훅 정책

- `pre-commit`: 파일/포맷 검사
- `pre-push`: `make verify` 실행
