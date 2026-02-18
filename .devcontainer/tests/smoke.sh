#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

log() {
  printf '[SMOKE] %s\n' "$*"
}

die() {
  printf '[SMOKE][ERROR] %s\n' "$*" >&2
  exit 1
}

copy_fixture() {
  local destination="$1"

  mkdir -p "${destination}/.devcontainer"
  cp -R "${REPO_ROOT}/.devcontainer/lib" "${destination}/.devcontainer/"
  cp "${REPO_ROOT}/.devcontainer/setup.sh" "${destination}/.devcontainer/setup.sh"
  cp "${REPO_ROOT}/Makefile" "${destination}/Makefile"
  cp "${REPO_ROOT}/pyproject.toml" "${destination}/pyproject.toml"
  cp "${REPO_ROOT}/.pre-commit-config.yaml" "${destination}/.pre-commit-config.yaml"
  cp "${REPO_ROOT}/requirements.txt" "${destination}/requirements.txt"
}

load_setup_libs() {
  # shellcheck source=/dev/null
  source .devcontainer/lib/config.sh
  # shellcheck source=/dev/null
  source .devcontainer/lib/core.sh
  # shellcheck source=/dev/null
  source .devcontainer/lib/workflows.sh
}

run_integration_smoke() {
  log "Running integration smoke in repository root"
  (
    cd "${REPO_ROOT}"
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

main() {
  temp_dir=""
  temp_dir="$(mktemp -d)"
  trap 'rm -rf "${temp_dir}"' EXIT

  run_integration_smoke
  test_broken_venv_recovery "${temp_dir}"
  test_core_hooks_path_guard "${temp_dir}"

  log "Smoke tests passed."
}

main "$@"
