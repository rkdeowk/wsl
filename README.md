# WSL Python Workspace

CI 없이 로컬에서 품질 게이트를 수행합니다.

## 초기 설정

```bash
# 0) requirements.txt 작성
#    (make init은 내부에서 pip install -r requirements.txt + 훅 설치 실행)

make init
make verify
```

## 개발 시퀀스

```bash
# 1) 코드 작성 후 자동 수정/포맷
make fix

# 2) 읽기 전용 검사
make verify

# 3) 커밋
git add -A
git commit -m "your message"

# 4) 푸시 (pre-push에서 make verify 자동 실행)
git push
```

## 배포/병합 전 점검

```bash
make check
make audit
```

## 자주 쓰는 명령

- `make fix` 자동 수정 + 포맷
- `make verify` 읽기 전용 검사
- `make check` 전체 게이트(`fix + hooks + verify`)
- `make audit` 취약점 점검

## 훅 정책

- `pre-commit`: 파일/포맷 검사
- `pre-push`: `make verify` 실행
