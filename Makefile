SHELL := /bin/bash
.DEFAULT_GOAL := help

VENV_BIN := .venv/bin
PYTHON := $(VENV_BIN)/python
PRE_COMMIT := $(VENV_BIN)/pre-commit
PIP_AUDIT := $(VENV_BIN)/pip-audit

RUFF := $(PYTHON) -m ruff
MYPY := $(PYTHON) -m mypy
PYTEST := $(PYTHON) -m pytest

FIND_FIRST_PYTHON_SOURCE := find . -path './.venv' -prune -o -type f -name '*.py' -print -quit
FIND_FIRST_PYTHON_TEST := find . -path './.venv' -prune -o -type f \( -name 'test_*.py' -o -name '*_test.py' \) -print -quit

.PHONY: help init install-hooks fix fmt lint test hooks verify check update-hooks audit

help:
	@echo "Targets:"
	@echo "  init          Setup local env"
	@echo "  install-hooks Install git hooks"
	@echo "  fix           Auto-fix and format"
	@echo "  fmt           Alias of fix"
	@echo "  lint          Ruff + mypy"
	@echo "  test          Pytest if tests exist"
	@echo "  hooks         Run pre-commit(all)"
	@echo "  verify        Read-only checks"
	@echo "  check         Full gate (fix+hooks+verify)"
	@echo "  update-hooks  Update hook versions"
	@echo "  audit         Dependency scan"

init:
	bash .devcontainer/setup.sh --strict

install-hooks:
	@if [ ! -x "$(PRE_COMMIT)" ]; then \
		echo "[ERROR] pre-commit is not installed. Run 'make init' first."; \
		exit 1; \
	fi
	$(PRE_COMMIT) install --install-hooks --hook-type pre-commit --hook-type pre-push

fix:
	$(RUFF) check --fix --no-cache .
	$(RUFF) format --no-cache .

fmt: fix

lint:
	$(RUFF) check --no-cache .
	@if $(FIND_FIRST_PYTHON_SOURCE) | grep -q .; then \
		$(MYPY) .; \
	else \
		echo "[INFO] No Python source files found. Skipping mypy."; \
	fi

test:
	@if $(FIND_FIRST_PYTHON_TEST) | grep -q .; then \
		$(PYTEST) -q; \
	else \
		echo "[INFO] No tests found. Skipping pytest."; \
	fi

hooks:
	$(PRE_COMMIT) run --all-files

verify: lint test

check:
	@$(MAKE) fix
	@$(MAKE) hooks
	@$(MAKE) verify

update-hooks:
	$(PRE_COMMIT) autoupdate

audit:
	$(PIP_AUDIT)
