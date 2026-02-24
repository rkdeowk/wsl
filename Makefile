SHELL := /bin/bash
.DEFAULT_GOAL := help

VENV_BIN := .venv/bin
PYTHON := $(VENV_BIN)/python
PIP_AUDIT := $(VENV_BIN)/pip-audit
RUFF := $(PYTHON) -m ruff
RESET_PATHS := .venv .mypy_cache .pytest_cache .ruff_cache

define run_setup_mode
bash .devcontainer/setup.sh $(1) --strict
endef

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
	$(call run_setup_mode,setup)

doctor:
	$(call run_setup_mode,doctor)

reset:
	rm -rf $(RESET_PATHS)
	@$(MAKE) bootstrap

fix:
	$(call require_executable,$(PYTHON))
	$(RUFF) check --fix --no-cache .
	$(RUFF) format --no-cache .

verify:
	$(call run_setup_mode,verify)

check:
	@$(MAKE) fix
	@$(MAKE) verify

audit:
	$(call require_executable,$(PYTHON))
	$(call require_executable,$(PIP_AUDIT))
	$(PIP_AUDIT)

smoke:
	bash .devcontainer/tests/smoke.sh
