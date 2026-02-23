SHELL := /bin/bash
.DEFAULT_GOAL := help

SETUP_SCRIPT := .devcontainer/setup.sh
SMOKE_SCRIPT := .devcontainer/tests/smoke.sh
VENV_BIN := .venv/bin
PYTHON := $(VENV_BIN)/python
PIP_AUDIT := $(VENV_BIN)/pip-audit
SETUP := bash $(SETUP_SCRIPT)

RUFF := $(PYTHON) -m ruff

define require_executable
	@if [ ! -x "$(1)" ]; then \
		echo "[ERROR] Missing $(1). Run 'make bootstrap'."; \
		exit 1; \
	fi
endef

.PHONY: help start bootstrap doctor reset fix verify check audit smoke

help:
	@echo "Targets:"
	@echo "  start         Run onboarding shortcut (bootstrap + doctor)"
	@echo "  bootstrap     Run first-time setup"
	@echo "  doctor        Check local environment"
	@echo "  fix           Auto-fix and format code"
	@echo "  verify        Run read-only checks"
	@echo "  check         Run fix, then verify"
	@echo "  audit         Scan dependencies for CVEs"
	@echo "  reset         Recreate virtual environment"
	@echo "  smoke         Run setup smoke tests"

start:
	@$(MAKE) bootstrap
	@$(MAKE) doctor

bootstrap:
	$(SETUP) setup --strict

doctor:
	$(SETUP) doctor --strict

reset:
	rm -rf .venv .mypy_cache .pytest_cache .ruff_cache
	@$(MAKE) bootstrap

fix:
	$(call require_executable,$(PYTHON))
	$(RUFF) check --fix --no-cache .
	$(RUFF) format --no-cache .

verify:
	$(SETUP) verify --strict

check:
	@$(MAKE) fix
	@$(MAKE) verify

audit:
	$(call require_executable,$(PYTHON))
	$(call require_executable,$(PIP_AUDIT))
	$(PIP_AUDIT)

smoke:
	bash $(SMOKE_SCRIPT)
