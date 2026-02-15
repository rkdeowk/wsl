#!/bin/bash
set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${REPO_ROOT}"

FAST_SETUP="${FAST_SETUP:-0}"
SETUP_STRICT="${SETUP_STRICT:-0}"
AUTOUPDATE_HOOKS="${AUTOUPDATE_HOOKS:-0}"
INSTALL_EDITABLE="${INSTALL_EDITABLE:-0}"

usage() {
    cat <<'EOF'
Usage: bash .devcontainer/setup.sh [options]

Options:
  --fast               Skip validation steps (same as FAST_SETUP=1)
  --strict             Stop on validation/install failure (same as SETUP_STRICT=1)
  --autoupdate-hooks   Run pre-commit autoupdate after hook install
  --editable           Install project as editable package
  -h, --help           Show this help message
EOF
}

parse_args() {
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --fast)
                FAST_SETUP=1
                ;;
            --strict)
                SETUP_STRICT=1
                ;;
            --autoupdate-hooks)
                AUTOUPDATE_HOOKS=1
                ;;
            --editable)
                INSTALL_EDITABLE=1
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                printf '[ERROR] Unknown option: %s\n' "$1" >&2
                usage
                exit 1
                ;;
        esac
        shift
    done
}

log() {
    local level="$1"
    shift
    printf '[%s] %s\n' "${level}" "$*"
}

run_step() {
    local description="$1"
    shift

    if "$@"; then
        return 0
    fi

    if [ "${SETUP_STRICT}" = "1" ]; then
        log ERROR "${description} failed."
        exit 1
    fi

    log WARNING "${description} failed. Continuing because SETUP_STRICT=0."
    return 1
}

require_canonical_files() {
    local file
    local missing=()
    local required=(
        "pyproject.toml"
        ".pre-commit-config.yaml"
        "Makefile"
        ".github/CODEOWNERS"
        ".github/dependabot.yml"
    )

    for file in "${required[@]}"; do
        if [ ! -f "${file}" ]; then
            missing+=("${file}")
        fi
    done

    if [ "${#missing[@]}" -eq 0 ]; then
        return
    fi

    log ERROR "Missing required repository files:"
    for file in "${missing[@]}"; do
        log ERROR "  - ${file}"
    done
    log ERROR "Commit baseline files to the repository."
    exit 1
}

setup_venv() {
    if [ ! -d .venv ]; then
        log INFO "Creating virtual environment at .venv"
        python -m venv .venv
    else
        log INFO "Using existing .venv"
    fi

    # shellcheck disable=SC1091
    source .venv/bin/activate
}

install_minimal_tooling() {
    run_step "Installing core dev tooling" \
        python -m pip install -U pre-commit ruff pytest mypy pip-audit || true
}

install_dependencies() {
    log INFO "Installing base tooling"
    python -m pip install -U pip setuptools wheel

    if [ "${INSTALL_EDITABLE}" = "1" ]; then
        log INFO "Installing project with dev dependencies (editable mode)"
        if run_step "pip install -e .[dev]" python -m pip install -e '.[dev]'; then
            return
        fi
    else
        log INFO "Installing project dev dependencies (non-editable mode)"
        if run_step "pip install .[dev]" python -m pip install '.[dev]'; then
            return
        fi
    fi

    log WARNING "Project dependency install failed. Installing minimal toolchain."
    install_minimal_tooling
}

install_hooks() {
    if [ ! -d .git ]; then
        log WARNING "No .git directory found. Skipping hook installation."
        return
    fi

    log INFO "Installing pre-commit hooks"
    run_step "pre-commit install" pre-commit install --install-hooks || true

    if [ "${AUTOUPDATE_HOOKS}" = "1" ]; then
        log INFO "Updating pre-commit hook versions"
        run_step "pre-commit autoupdate" pre-commit autoupdate || true
    fi
}

has_python_sources() {
    find . -path './.venv' -prune -o -type f -name '*.py' -print -quit | grep -q .
}

has_python_tests() {
    find . -path './.venv' -prune -o -type f \( -name 'test_*.py' -o -name '*_test.py' \) -print -quit | grep -q .
}

run_validation() {
    if [ "${FAST_SETUP}" = "1" ]; then
        log INFO "FAST_SETUP=1, skipping validation steps."
        return
    fi

    log INFO "Running local validation"
    if ! pre-commit run --all-files; then
        log INFO "Re-running pre-commit after applying autofixes"
        run_step "pre-commit run --all-files (second pass)" pre-commit run --all-files || true
    fi

    run_step "ruff check" python -m ruff check --no-cache . || true

    if has_python_sources; then
        run_step "mypy" python -m mypy . || true
    else
        log INFO "No Python source files found. Skipping mypy."
    fi

    if has_python_tests; then
        run_step "pytest" python -m pytest -q || true
    else
        log INFO "No tests found. Skipping pytest."
    fi
}

main() {
    parse_args "$@"
    command -v python >/dev/null 2>&1 || {
        log ERROR "python command is required."
        exit 1
    }
    command -v git >/dev/null 2>&1 || {
        log ERROR "git command is required."
        exit 1
    }

    require_canonical_files
    setup_venv
    install_dependencies
    install_hooks
    run_validation
    log INFO "Development environment setup completed."
}

main "$@"
