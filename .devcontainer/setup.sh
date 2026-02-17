#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
VENV_DIR=".venv"
REQUIREMENTS_FILE="requirements.txt"
REQUIRED_FILES=("pyproject.toml" ".pre-commit-config.yaml" "Makefile" "${REQUIREMENTS_FILE}")
REQUIRED_DEV_TOOLS=("pre-commit" "ruff" "pytest" "mypy" "pip-audit")

FAST_SETUP="${FAST_SETUP:-0}"
SETUP_STRICT="${SETUP_STRICT:-0}"
AUTOUPDATE_HOOKS="${AUTOUPDATE_HOOKS:-0}"
INSTALL_EDITABLE="${INSTALL_EDITABLE:-0}"

cd "${REPO_ROOT}"

usage() {
  cat <<'EOF'
Usage: bash .devcontainer/setup.sh [options]

Options:
  --fast               Skip validation steps (FAST_SETUP=1)
  --strict             Stop on validation/install failure (SETUP_STRICT=1)
  --autoupdate-hooks   Run pre-commit autoupdate
  --editable           Also install project as editable package
  -h, --help           Show this help message
EOF
}

log() {
  local level="$1"
  shift
  printf '[%s] %s\n' "${level}" "$*"
}

die() {
  log ERROR "$*"
  exit 1
}

is_on() {
  [ "$1" = "1" ]
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --fast) FAST_SETUP=1 ;;
      --strict) SETUP_STRICT=1 ;;
      --autoupdate-hooks) AUTOUPDATE_HOOKS=1 ;;
      --editable) INSTALL_EDITABLE=1 ;;
      -h|--help) usage; exit 0 ;;
      *) die "Unknown option: $1" ;;
    esac
    shift
  done
}

require_tools() {
  local cmd
  for cmd in python git; do
    command -v "${cmd}" >/dev/null 2>&1 || die "${cmd} command is required."
  done
}

check_required_files() {
  local file
  local missing=0
  for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "${file}" ]; then
      log ERROR "Missing file: ${file}"
      missing=1
    fi
  done
  [ "${missing}" -eq 0 ] || die "Required files are missing."
}

run_or_warn() {
  local title="$1"
  shift
  if "$@"; then
    return 0
  fi
  if is_on "${SETUP_STRICT}"; then
    die "${title} failed."
  fi
  log WARNING "${title} failed (SETUP_STRICT=0)."
  return 1
}

pip_install() {
  python -m pip install "$@"
}

has_matching_files() {
  find . -path "./${VENV_DIR}" -prune -o -type f "$@" -print -quit | grep -q .
}

setup_venv() {
  if [ -d "${VENV_DIR}" ]; then
    log INFO "Using existing ${VENV_DIR}"
  else
    log INFO "Creating virtual environment at ${VENV_DIR}"
    python -m venv "${VENV_DIR}"
  fi
  # shellcheck disable=SC1091
  source "${VENV_DIR}/bin/activate"
}

verify_required_dev_tools() {
  local tool
  local missing=0
  for tool in "${REQUIRED_DEV_TOOLS[@]}"; do
    if [ ! -x "${VENV_DIR}/bin/${tool}" ]; then
      log ERROR "Missing ${tool} in ${VENV_DIR}. Add it to ${REQUIREMENTS_FILE}."
      missing=1
    fi
  done
  [ "${missing}" -eq 0 ]
}

install_dependencies() {
  log INFO "Installing base tooling"
  python -m pip install -U pip setuptools wheel

  run_or_warn "pip install -r ${REQUIREMENTS_FILE}" pip_install -r "${REQUIREMENTS_FILE}"

  if is_on "${INSTALL_EDITABLE}"; then
    run_or_warn "pip install -e ." pip_install -e .
  fi

  run_or_warn "Verify required dev tools" verify_required_dev_tools
}

install_hooks() {
  if [ ! -d .git ]; then
    log WARNING "No .git directory found. Skipping hook installation."
    return
  fi

  run_or_warn "pre-commit install" \
    pre-commit install --install-hooks --hook-type pre-commit --hook-type pre-push || true

  if is_on "${AUTOUPDATE_HOOKS}"; then
    run_or_warn "pre-commit autoupdate" pre-commit autoupdate || true
  fi
}

run_validation() {
  if is_on "${FAST_SETUP}"; then
    log INFO "FAST_SETUP=1, skipping validation."
    return
  fi

  log INFO "Running local validation"
  if ! pre-commit run --all-files; then
    log INFO "Retrying pre-commit after autofixes"
    run_or_warn "pre-commit run --all-files (second pass)" pre-commit run --all-files || true
  fi

  run_or_warn "ruff check" python -m ruff check --no-cache . || true

  if has_matching_files -name '*.py'; then
    run_or_warn "mypy" python -m mypy . || true
  else
    log INFO "No Python source files found. Skipping mypy."
  fi

  if has_matching_files \( -name 'test_*.py' -o -name '*_test.py' \); then
    run_or_warn "pytest" python -m pytest -q || true
  else
    log INFO "No tests found. Skipping pytest."
  fi
}

main() {
  parse_args "$@"
  require_tools
  check_required_files
  setup_venv
  install_dependencies
  install_hooks
  run_validation
  log INFO "Setup complete."
}

main "$@"
