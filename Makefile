SHELL := /bin/bash
.DEFAULT_GOAL := help

PYTHON := .venv/bin/python
PRE_COMMIT := .venv/bin/pre-commit
PIP_AUDIT := .venv/bin/pip-audit

.PHONY: help init install-hooks fmt lint test check update-hooks audit

help:
	@echo "Targets:"
	@echo "  init          Bootstrap local dev environment"
	@echo "  install-hooks Install git hooks"
	@echo "  fmt           Run formatters and autofixes"
	@echo "  lint          Run static analysis"
	@echo "  test          Run tests when present"
	@echo "  check         Run full local quality gate"
	@echo "  update-hooks  Update pre-commit hook revisions"
	@echo "  audit         Scan dependencies for vulnerabilities"

init:
	bash .devcontainer/setup.sh

install-hooks:
	@if [ ! -x "$(PRE_COMMIT)" ]; then \
		echo "[ERROR] pre-commit is not installed. Run 'make init' first."; \
		exit 1; \
	fi
	$(PRE_COMMIT) install --install-hooks

fmt:
	$(PYTHON) -m ruff check --fix --no-cache .
	$(PYTHON) -m ruff format --no-cache .

lint:
	$(PYTHON) -m ruff check --no-cache .
	@if find . -path './.venv' -prune -o -type f -name '*.py' -print | grep -q .; then \
		$(PYTHON) -m mypy .; \
	else \
		echo "[INFO] No Python source files found. Skipping mypy."; \
	fi

test:
	@if find . -path './.venv' -prune -o -type f \( -name 'test_*.py' -o -name '*_test.py' \) -print | grep -q .; then \
		$(PYTHON) -m pytest -q; \
	else \
		echo "[INFO] No tests found. Skipping pytest."; \
	fi

check: fmt lint test
	$(PRE_COMMIT) run --all-files

update-hooks:
	$(PRE_COMMIT) autoupdate

audit:
	$(PIP_AUDIT)
