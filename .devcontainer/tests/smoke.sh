#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# shellcheck source=/dev/null
source "${REPO_ROOT}/.devcontainer/lib/config.sh"

log() {
  printf '[SMOKE] %s\n' "$*"
}

die() {
  printf '[SMOKE][ERROR] %s\n' "$*" >&2
  exit 1
}

copy_fixture() {
  local destination="$1"
  local file

  mkdir -p "${destination}/.devcontainer"
  cp -R "${REPO_ROOT}/.devcontainer/lib" "${destination}/.devcontainer/"
  cp "${REPO_ROOT}/.devcontainer/setup.sh" "${destination}/.devcontainer/setup.sh"

  for file in "${REQUIRED_FILES[@]}"; do
    mkdir -p "$(dirname "${destination}/${file}")"
    cp "${REPO_ROOT}/${file}" "${destination}/${file}"
  done
}

load_setup_libs() {
  # shellcheck source=/dev/null
  source .devcontainer/lib/core.sh
  # shellcheck source=/dev/null
  source .devcontainer/lib/workflows.sh
}

run_integration_smoke() {
  local case_dir="$1/integration"
  mkdir -p "${case_dir}"
  copy_fixture "${case_dir}"

  log "Running integration smoke in isolated fixture"
  (
    cd "${case_dir}"
    git init -q
    bash .devcontainer/setup.sh setup --fast --strict
    bash .devcontainer/setup.sh doctor --strict
    bash .devcontainer/setup.sh verify --strict
  )
}

test_broken_venv_recovery() {
  local case_dir="$1/broken-venv"
  mkdir -p "${case_dir}"
  copy_fixture "${case_dir}"
  mkdir -p "${case_dir}/.venv"

  log "Testing recovery from incomplete .venv"
  (
    cd "${case_dir}"
    load_setup_libs
    activate_or_create_venv
    [ -x ".venv/bin/python" ] || die "Expected .venv/bin/python to exist after recovery."
  )
}

test_core_hooks_path_guard() {
  local case_dir="$1/hooks-path"
  mkdir -p "${case_dir}"
  copy_fixture "${case_dir}"

  log "Testing core.hooksPath guard"
  (
    cd "${case_dir}"
    git init -q
    git config --local core.hooksPath .githooks-custom

    load_setup_libs

    if verify_git_hooks_installed; then
      die "Expected verify_git_hooks_installed to fail when core.hooksPath is set."
    fi
  )
}

test_runtime_policy_enforcement() {
  local case_dir="$1/runtime-policy"
  mkdir -p "${case_dir}"
  copy_fixture "${case_dir}"

  log "Testing runtime policy enforcement"
  (
    cd "${case_dir}"
    load_setup_libs

    is_container_runtime() { return 1; }

    ALLOW_HOST_RUN=0
    if ( enforce_runtime_policy ); then
      die "Expected enforce_runtime_policy to fail when ALLOW_HOST_RUN=0 outside container."
    fi

    ALLOW_HOST_RUN=1
    if ! ( enforce_runtime_policy ); then
      die "Expected enforce_runtime_policy to pass when ALLOW_HOST_RUN=1."
    fi
  )
}

test_pip_install_uses_venv_python() {
  local case_dir="$1/pip-install-python"
  mkdir -p "${case_dir}"
  copy_fixture "${case_dir}"

  log "Testing pip_install uses fixture venv python"
  (
    cd "${case_dir}"
    load_setup_libs
    require_host_tools
    activate_or_create_venv

    local trace_output=""
    trace_output="$(
      (
        set -x
        pip_install --help >/dev/null
      ) 2>&1
    )" || die "pip_install --help failed."

    case "${trace_output}" in
      *"${case_dir}/.venv/bin/python"*|*".venv/bin/python -m pip install"*) ;;
      *)
        die "Expected pip_install to use ${case_dir}/.venv/bin/python but got: ${trace_output}"
        ;;
    esac
  )
}

main() {
  temp_dir=""
  temp_dir="$(mktemp -d)"
  trap 'rm -rf "${temp_dir}"' EXIT

  run_integration_smoke "${temp_dir}"
  test_broken_venv_recovery "${temp_dir}"
  test_core_hooks_path_guard "${temp_dir}"
  test_runtime_policy_enforcement "${temp_dir}"
  test_pip_install_uses_venv_python "${temp_dir}"

  log "Smoke tests passed."
}

main "$@"
