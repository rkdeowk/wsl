#!/bin/bash
set -euo pipefail

mkdir -p .github

# pyproject.toml 생성
if [ ! -f pyproject.toml ]; then
    cat <<EOF > pyproject.toml
[project]
name = "wsl"
version = "0.1.0"
requires-python = ">=3.12"
dependencies = []

[project.optional-dependencies]
dev = ["pre-commit"]

[tool.ruff]
line-length = 100
target-version = "py312"
EOF
fi

# .pre-commit-config.yaml 생성 (Hook ID 수정됨: ruff-check -> ruff)
if [ ! -f .pre-commit-config.yaml ]; then
    cat <<EOF > .pre-commit-config.yaml
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.5.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
      - id: check-added-large-files
  - repo: https://github.com/astral-sh/ruff-pre-commit
    rev: v0.3.0
    hooks:
      - id: ruff
        args: [--fix]
      - id: ruff-format
EOF
fi

# 기타 설정...
if [ ! -f .github/CODEOWNERS ]; then echo '* @your-github-handle' > .github/CODEOWNERS; fi

# Python 환경 설정
python -m venv .venv || true
source .venv/bin/activate
python -m pip install -U pip pre-commit

if [ -f pyproject.toml ]; then
    python -m pip install -e '.[dev]' 2>/dev/null || python -m pip install -e . 2>/dev/null || true
fi

if [ -d .git ]; then
    pre-commit install --install-hooks || true
fi
