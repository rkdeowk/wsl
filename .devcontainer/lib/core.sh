#!/usr/bin/env bash

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

valid_mode() {
  case "$1" in
    setup|doctor|verify) return 0 ;;
    *) return 1 ;;
  esac
}

normalize_boolean_flag() {
  local flag_name="$1"
  local raw_value="${!flag_name:-0}"

  case "${raw_value,,}" in
    1|true|yes|on) printf -v "${flag_name}" '%s' "1" ;;
    0|false|no|off|'') printf -v "${flag_name}" '%s' "0" ;;
    *)
      die "${flag_name} must be one of: 0, 1, true, false, yes, no, on, off."
      ;;
  esac
}

normalize_runtime_flags() {
  local flag_name
  for flag_name in FAST_SETUP SETUP_STRICT AUTOUPDATE_HOOKS INSTALL_EDITABLE; do
    normalize_boolean_flag "${flag_name}"
  done

  if ! valid_mode "${MODE}"; then
    die "MODE must be one of: setup, doctor, verify."
  fi
}

set_mode() {
  local next_mode="$1"

  if ! valid_mode "${next_mode}"; then
    die "Unknown mode: ${next_mode}"
  fi

  if ! valid_mode "${MODE}"; then
    MODE="${DEFAULT_MODE}"
  fi

  if [ "${MODE}" != "${DEFAULT_MODE}" ] && [ "${MODE}" != "${next_mode}" ]; then
    die "Use only one mode: setup, doctor, or verify."
  fi

  MODE="${next_mode}"
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      setup|doctor|verify) set_mode "$1" ;;
      --mode)
        [ "$#" -gt 1 ] || die "--mode requires a value: setup, doctor, or verify."
        shift
        set_mode "$1"
        ;;
      --mode=*) set_mode "${1#--mode=}" ;;
      --doctor) set_mode "doctor" ;;
      --verify) set_mode "verify" ;;
      --fast) FAST_SETUP=1 ;;
      --strict) SETUP_STRICT=1 ;;
      --autoupdate-hooks) AUTOUPDATE_HOOKS=1 ;;
      --editable) INSTALL_EDITABLE=1 ;;
      -h|--help) usage; exit 0 ;;
      *) die "Unknown option or mode: $1" ;;
    esac
    shift
  done
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
  return 0
}
