SHELL := /bin/bash
.DEFAULT_GOAL := help

SETUP_SCRIPT := .devcontainer/setup.sh
SMOKE_SCRIPT := .devcontainer/tests/smoke.sh
VENV_BIN := .venv/bin
PYTHON := $(VENV_BIN)/python
PIP_AUDIT := $(VENV_BIN)/pip-audit

RUFF := $(PYTHON) -m ruff

define require_executable
	@if [ ! -x "$(1)" ]; then \
		echo "[ERROR] Missing $(1). Run 'make bootstrap'."; \
		exit 1; \
	fi
endef

.PHONY: help bootstrap doctor reset fix verify check audit smoke

help:
	@echo "Targets:"
	@echo "  bootstrap     One-shot onboarding setup"
	@echo "  doctor        Diagnose local setup"
	@echo "  reset         Recreate local env from scratch"
	@echo "  fix           Auto-fix and format"
	@echo "  verify        Read-only checks"
	@echo "  check         Full gate (fix+verify)"
	@echo "  audit         Dependency scan"
	@echo "  smoke         Run setup smoke tests"

bootstrap:
	bash $(SETUP_SCRIPT) setup --strict

doctor:
	bash $(SETUP_SCRIPT) doctor --strict

reset:
	rm -rf .venv .mypy_cache .pytest_cache .ruff_cache
	@$(MAKE) bootstrap

fix:
	$(call require_executable,$(PYTHON))
	$(RUFF) check --fix --no-cache .
	$(RUFF) format --no-cache .

verify:
	bash $(SETUP_SCRIPT) verify --strict

check:
	@$(MAKE) fix
	@$(MAKE) verify

audit:
	$(call require_executable,$(PYTHON))
	$(call require_executable,$(PIP_AUDIT))
	$(PIP_AUDIT)

smoke:
	bash $(SMOKE_SCRIPT)
