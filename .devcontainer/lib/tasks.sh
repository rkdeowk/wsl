#!/usr/bin/env bash

task_setup() {
  require_host_tools
  check_required_files
  activate_or_create_venv
  install_dependencies
  install_git_hooks
  run_setup_validation
  log INFO "Setup complete."
}

task_doctor() {
  log INFO "Running environment diagnostics"
  check_required_files

  require_existing_venv
  log INFO "[OK] $(${VENV_DIR}/bin/python --version 2>&1)"

  if ! verify_required_dev_tools 1; then
    die "Missing required dev tools in ${VENV_DIR}. Run 'make bootstrap' (or 'make reset' if still broken)."
  fi

  if verify_git_hooks_installed; then
    if is_git_repo; then
      log INFO "[OK] Git hooks installed ($(git_hooks_dir): pre-commit, pre-push)"
    fi
  elif is_git_repo; then
    die "Git hook verification failed. Fix the errors above, then run 'make bootstrap'."
  fi

  log INFO "Doctor checks passed."
}

task_verify() {
  check_required_files
  require_existing_venv
  run_readonly_checks
}

dispatch_mode() {
  local mode="$1"
  case "${mode}" in
    setup) task_setup ;;
    doctor) task_doctor ;;
    verify) task_verify ;;
    *) die "Unknown mode: ${mode}" ;;
  esac
}
