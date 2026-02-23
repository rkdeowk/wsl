#!/usr/bin/env bash

# Shared constants for setup entry points.
readonly ENTRY_SCRIPT_REL=".devcontainer/setup.sh"
readonly VENV_DIR=".venv"
readonly REQUIREMENTS_FILE="requirements.txt"
readonly DEFAULT_MODE="setup"

# Files and tools that must exist in this repository.
readonly -a REQUIRED_FILES=("pyproject.toml" ".pre-commit-config.yaml" "Makefile" "${REQUIREMENTS_FILE}")
readonly -a REQUIRED_DEV_TOOLS=("pre-commit" "ruff" "mypy" "pytest" "pip-audit")

# Runtime flags (all booleans are normalized to 0/1 in core.sh).
MODE="${MODE:-${DEFAULT_MODE}}"
FAST_SETUP="${FAST_SETUP:-0}"
SETUP_STRICT="${SETUP_STRICT:-0}"
AUTOUPDATE_HOOKS="${AUTOUPDATE_HOOKS:-0}"
INSTALL_EDITABLE="${INSTALL_EDITABLE:-0}"
ALLOW_HOST_RUN="${ALLOW_HOST_RUN:-0}"
