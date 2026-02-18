#!/usr/bin/env bash

venv_executable_path() {
  local executable="$1"
  printf '%s/bin/%s' "${VENV_DIR}" "${executable}"
}

has_venv_executable() {
  [ -x "$(venv_executable_path "$1")" ]
}

is_git_available() {
  command -v git >/dev/null 2>&1
}

is_git_repo() {
  is_git_available && git rev-parse --is-inside-work-tree >/dev/null 2>&1
}

ensure_git_repo_or_skip() {
  local context="$1"

  if ! is_git_available; then
    log WARNING "git command not found. Skipping ${context}."
    return 1
  fi

  if ! is_git_repo; then
    log WARNING "Not inside a git repository. Skipping ${context}."
    return 1
  fi

  return 0
}

git_hooks_dir() {
  git rev-parse --git-path hooks
}

git_core_hooks_path() {
  git config --get core.hooksPath 2>/dev/null || true
}

verify_supported_git_hooks_config() {
  local hooks_path
  hooks_path="$(git_core_hooks_path)"

  if [ -n "${hooks_path}" ]; then
    log ERROR "Unsupported git config: core.hooksPath='${hooks_path}'."
    log ERROR "Unset it in this repository: git config --unset-all core.hooksPath"
    return 1
  fi

  return 0
}

require_host_tools() {
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

pip_install() {
  python -m pip install "$@"
}

has_matching_files() {
  find . -path "./${VENV_DIR}" -prune -o -type f "$@" -print -quit | grep -q .
}

activate_or_create_venv() {
  if [ -d "${VENV_DIR}" ] && [ ! -x "${VENV_DIR}/bin/python" ]; then
    log WARNING "${VENV_DIR} exists but is incomplete. Recreating it."
    rm -rf "${VENV_DIR}"
  fi

  if [ -x "${VENV_DIR}/bin/python" ]; then
    log INFO "Using existing ${VENV_DIR}"
  else
    log INFO "Creating virtual environment at ${VENV_DIR}"
    python -m venv "${VENV_DIR}"
  fi

  [ -f "${VENV_DIR}/bin/activate" ] || die "Missing ${VENV_DIR}/bin/activate after venv setup."

  # shellcheck disable=SC1091
  source "${VENV_DIR}/bin/activate"
}

require_existing_venv() {
  if [ ! -x "${VENV_DIR}/bin/python" ]; then
    die "Missing ${VENV_DIR}/bin/python. Run 'make bootstrap' first."
  fi

  # shellcheck disable=SC1091
  source "${VENV_DIR}/bin/activate"
}

verify_required_dev_tools() {
  local show_ok="${1:-0}"
  local tool
  local missing=0

  for tool in "${REQUIRED_DEV_TOOLS[@]}"; do
    if has_venv_executable "${tool}"; then
      if is_on "${show_ok}"; then
        log INFO "[OK] ${tool}"
      fi
    else
      log ERROR "Missing ${tool} in ${VENV_DIR}. Add it to ${REQUIREMENTS_FILE}."
      missing=1
    fi
  done

  [ "${missing}" -eq 0 ]
}

verify_git_hooks_installed() {
  if ! ensure_git_repo_or_skip "hook checks"; then
    return 0
  fi

  if ! verify_supported_git_hooks_config; then
    return 1
  fi

  local hooks_dir
  hooks_dir="$(git_hooks_dir)"

  local hook
  local missing=0

  for hook in pre-commit pre-push; do
    if [ ! -f "${hooks_dir}/${hook}" ]; then
      log ERROR "Missing ${hooks_dir}/${hook}. Run 'make bootstrap'."
      missing=1
    fi
  done

  [ "${missing}" -eq 0 ]
}

install_dependencies() {
  log INFO "Installing dependencies from ${REQUIREMENTS_FILE}"
  run_or_warn "pip install -r ${REQUIREMENTS_FILE}" pip_install -r "${REQUIREMENTS_FILE}"

  if is_on "${INSTALL_EDITABLE}"; then
    run_or_warn "pip install -e ." pip_install -e .
  fi

  run_or_warn "Verify required dev tools" verify_required_dev_tools
}

install_git_hooks() {
  if ! ensure_git_repo_or_skip "hook installation"; then
    return
  fi

  run_or_warn "Verify git hook configuration" verify_supported_git_hooks_config

  run_or_warn "pre-commit install" pre-commit install \
    --install-hooks \
    --hook-type pre-commit \
    --hook-type pre-push

  if is_on "${AUTOUPDATE_HOOKS}"; then
    run_or_warn "pre-commit autoupdate" pre-commit autoupdate
  fi
}

run_readonly_checks() {
  run_or_warn "ruff check" python -m ruff check --no-cache .

  if has_matching_files -name '*.py'; then
    run_or_warn "mypy" python -m mypy .
  else
    log INFO "No Python source files found. Skipping mypy."
  fi

  if has_matching_files \( -name 'test_*.py' -o -name '*_test.py' \); then
    run_or_warn "pytest" python -m pytest -q
  else
    log INFO "No tests found. Skipping pytest."
  fi
}

run_setup_validation() {
  if is_on "${FAST_SETUP}"; then
    log INFO "FAST_SETUP=1, skipping validation."
    return
  fi

  log INFO "Running local validation"
  if ! pre-commit run --all-files; then
    log INFO "Retrying pre-commit after autofixes"
    run_or_warn "pre-commit run --all-files (second pass)" pre-commit run --all-files
  fi

  run_readonly_checks
}
