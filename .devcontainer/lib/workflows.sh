#!/usr/bin/env bash

# ---- Runtime Policy -----------------------------------------------------
is_container_runtime() {
  if [ -f "/.dockerenv" ] || [ -f "/run/.containerenv" ]; then
    return 0
  fi

  if [ -r "/proc/1/cgroup" ] && grep -Eiq '(docker|containerd|kubepods|podman|libpod|lxc)' /proc/1/cgroup; then
    return 0
  fi

  return 1
}

enforce_runtime_policy() {
  if is_container_runtime; then
    return 0
  fi

  if is_on "${ALLOW_HOST_RUN}"; then
    log WARNING "Running outside Dev Container because ALLOW_HOST_RUN=1."
    return 0
  fi

  die "Outside Dev Container is blocked by default. Try: Dev Containers: Reopen in Container"
}

# ---- Git Hooks ----------------------------------------------------------
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

verify_supported_git_hooks_config() {
  local hooks_path
  hooks_path="$(git config --get core.hooksPath 2>/dev/null || true)"

  if [ -n "${hooks_path}" ]; then
    log ERROR "Unsupported git config: core.hooksPath='${hooks_path}'."
    log ERROR "Fix: git config --unset-all core.hooksPath"
    return 1
  fi

  return 0
}

verify_git_hooks_installed() {
  ensure_git_repo_or_skip "hook checks" || return 0
  verify_supported_git_hooks_config || return 1

  local hooks_dir
  hooks_dir="$(git_hooks_dir)"

  local hook
  local missing=0

  for hook in pre-commit pre-push; do
    if [ ! -x "${hooks_dir}/${hook}" ]; then
      log ERROR "Missing executable hook: ${hooks_dir}/${hook}. Fix: make bootstrap"
      missing=1
    fi
  done

  [ "${missing}" -eq 0 ]
}

install_git_hooks() {
  ensure_git_repo_or_skip "hook installation" || return 0

  run_or_warn "Verify git hook configuration" verify_supported_git_hooks_config
  run_or_warn "pre-commit install" pre-commit install \
    --install-hooks \
    --hook-type pre-commit \
    --hook-type pre-push

  if is_on "${AUTOUPDATE_HOOKS}"; then
    run_or_warn "pre-commit autoupdate" pre-commit autoupdate
  fi
}

# ---- Python / Venv ------------------------------------------------------
venv_executable_path() {
  local executable="$1"
  printf '%s/bin/%s' "${VENV_DIR}" "${executable}"
}

require_host_tools() {
  if command -v python >/dev/null 2>&1; then
    PYTHON_CMD="python"
    return 0
  fi

  if command -v python3 >/dev/null 2>&1; then
    PYTHON_CMD="python3"
    log WARNING "python command not found. Falling back to python3."
    return 0
  fi

  die "Python is missing. Fix: install python3 (with venv/pip), then run make bootstrap"
}

source_venv() {
  [ -f "${VENV_DIR}/bin/activate" ] || die "Missing ${VENV_DIR}/bin/activate. Fix: make bootstrap"

  # shellcheck disable=SC1091
  source "${VENV_DIR}/bin/activate"
}

activate_or_create_venv() {
  local python_cmd
  python_cmd="${PYTHON_CMD:-python}"

  if [ -d "${VENV_DIR}" ] && [ ! -x "${VENV_DIR}/bin/python" ]; then
    log WARNING "${VENV_DIR} exists but is incomplete. Recreating it."
    rm -rf "${VENV_DIR}"
  fi

  if [ -x "${VENV_DIR}/bin/python" ]; then
    log INFO "Using existing ${VENV_DIR}"
  else
    log INFO "Creating virtual environment at ${VENV_DIR}"
    "${python_cmd}" -m venv "${VENV_DIR}"
  fi

  source_venv
}

require_existing_venv() {
  [ -x "${VENV_DIR}/bin/python" ] || die "Missing ${VENV_DIR}/bin/python. Fix: make bootstrap"
  source_venv
}

# ---- Dependency Install -------------------------------------------------
check_required_files() {
  local file
  local missing=0

  for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "${file}" ]; then
      log ERROR "Missing file: ${file}"
      missing=1
    fi
  done

  [ "${missing}" -eq 0 ] || die "Required files are missing. Fix: restore files, then run make bootstrap"
}

pip_install() {
  local venv_python
  venv_python="$(venv_executable_path python)"
  [ -x "${venv_python}" ] || die "Missing ${venv_python}. Fix: make bootstrap"
  "${venv_python}" -m pip install "$@"
}

verify_required_dev_tools() {
  local show_ok="${1:-0}"
  local tool
  local missing=0

  for tool in "${REQUIRED_DEV_TOOLS[@]}"; do
    if [ -x "$(venv_executable_path "${tool}")" ]; then
      if is_on "${show_ok}"; then
        log INFO "[OK] ${tool}"
      fi
    else
      log ERROR "Missing ${tool} in ${VENV_DIR}. Fix: add to ${REQUIREMENTS_FILE}, then run make bootstrap"
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

# ---- Validation Checks --------------------------------------------------
has_matching_files() {
  find . \
    -path "./${VENV_DIR}" -prune -o \
    -path "./build" -prune -o \
    -path "./dist" -prune -o \
    -type f "$@" -print -quit | grep -q .
}

run_ruff_check() {
  local run_cmd="$1"
  local venv_python
  venv_python="$(venv_executable_path python)"
  "${run_cmd}" "ruff check" "${venv_python}" -m ruff check --no-cache .
}

run_mypy_check() {
  local run_cmd="$1"
  local venv_python
  venv_python="$(venv_executable_path python)"

  if has_matching_files -name '*.py'; then
    "${run_cmd}" "mypy" "${venv_python}" -m mypy .
  else
    log INFO "No Python source files found. Skipping mypy."
  fi
}

run_pytest_check() {
  local run_cmd="$1"
  local venv_python
  venv_python="$(venv_executable_path python)"

  if has_matching_files \( -name 'test_*.py' -o -name '*_test.py' \); then
    "${run_cmd}" "pytest" "${venv_python}" -m pytest -q
  else
    log INFO "No tests found. Skipping pytest."
  fi
}

run_readonly_checks() {
  local run_cmd="run_or_warn"
  if is_on "${SETUP_STRICT}"; then
    run_cmd="run_or_fail"
  fi

  run_ruff_check "${run_cmd}"
  run_mypy_check "${run_cmd}"
  run_pytest_check "${run_cmd}"
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
