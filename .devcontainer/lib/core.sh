#!/usr/bin/env bash

# ---- Help ---------------------------------------------------------------
usage() {
  cat <<EOF
Usage:
  bash ${ENTRY_SCRIPT_REL} [setup|doctor|verify] [options]
  bash ${ENTRY_SCRIPT_REL} [options]

Modes:
  setup                Full environment setup (default)
  doctor               Environment diagnostics only
  verify               Read-only checks only

Options:
  --mode MODE          Explicitly select mode (setup|doctor|verify)
  --doctor             Legacy alias for mode "doctor"
  --verify             Legacy alias for mode "verify"
  --fast               Skip validation steps (FAST_SETUP=1)
  --strict             Stop on validation/install failure (SETUP_STRICT=1)
  --autoupdate-hooks   Run pre-commit autoupdate
  --editable           Also install project as editable package
  -h, --help           Show this help message

Runtime policy:
  Dev Container only by default.
  To bypass on host: ALLOW_HOST_RUN=1 bash ${ENTRY_SCRIPT_REL} ...
EOF
}

# ---- Parsing ------------------------------------------------------------
valid_mode() {
  case "$1" in
    setup|doctor|verify) return 0 ;;
    *) return 1 ;;
  esac
}

set_mode() {
  local next_mode="$1"

  if ! valid_mode "${next_mode}"; then
    die "Unknown mode: ${next_mode}. Try: bash ${ENTRY_SCRIPT_REL} --help"
  fi

  valid_mode "${MODE}" || MODE="${DEFAULT_MODE}"

  if [ "${MODE}" != "${DEFAULT_MODE}" ] && [ "${MODE}" != "${next_mode}" ]; then
    die "Only one mode is allowed. Try: bash ${ENTRY_SCRIPT_REL} --help"
  fi

  MODE="${next_mode}"
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      setup|doctor|verify) set_mode "$1" ;;
      --mode)
        [ "$#" -gt 1 ] || die "Missing value for --mode. Try: bash ${ENTRY_SCRIPT_REL} --help"
        shift
        set_mode "$1"
        ;;
      --mode=*) set_mode "${1#--mode=}" ;;
      --doctor|--verify) set_mode "${1#--}" ;;
      --fast) FAST_SETUP=1 ;;
      --strict) SETUP_STRICT=1 ;;
      --autoupdate-hooks) AUTOUPDATE_HOOKS=1 ;;
      --editable) INSTALL_EDITABLE=1 ;;
      -h|--help) usage; exit 0 ;;
      *) die "Unknown option or mode: $1. Try: bash ${ENTRY_SCRIPT_REL} --help" ;;
    esac
    shift
  done
}

# ---- Validation ---------------------------------------------------------
is_on() {
  [ "$1" = "1" ]
}

normalize_boolean_flag() {
  local flag_name="$1"
  local raw_value="${!flag_name:-0}"

  case "${raw_value,,}" in
    1|true|yes|on) printf -v "${flag_name}" '%s' "1" ;;
    0|false|no|off|'') printf -v "${flag_name}" '%s' "0" ;;
    *)
      die "${flag_name} has invalid value '${raw_value}'. Try: bash ${ENTRY_SCRIPT_REL} --help"
      ;;
  esac
}

normalize_runtime_flags() {
  local flag_name
  for flag_name in FAST_SETUP SETUP_STRICT AUTOUPDATE_HOOKS INSTALL_EDITABLE ALLOW_HOST_RUN; do
    normalize_boolean_flag "${flag_name}"
  done

  if ! valid_mode "${MODE}"; then
    die "MODE has invalid value '${MODE}'. Try: bash ${ENTRY_SCRIPT_REL} --help"
  fi
}

# ---- Execution Helpers --------------------------------------------------
log() {
  local level="$1"
  shift
  printf '[%s] %s\n' "${level}" "$*"
}

die() {
  log ERROR "$*"
  exit 1
}

run_or_warn() {
  local title="$1"
  shift

  if "$@"; then
    return 0
  fi

  if is_on "${SETUP_STRICT}"; then
    die "${title} failed. Try: make bootstrap"
  fi

  log WARNING "${title} failed (SETUP_STRICT=0)."
  return 0
}

run_or_fail() {
  local title="$1"
  shift

  "$@" || die "${title} failed. Try: make bootstrap"
}
