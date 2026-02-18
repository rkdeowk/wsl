#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"

cd "${REPO_ROOT}"

# shellcheck source=/dev/null
source "${LIB_DIR}/config.sh"
# shellcheck source=/dev/null
source "${LIB_DIR}/core.sh"
# shellcheck source=/dev/null
source "${LIB_DIR}/workflows.sh"
# shellcheck source=/dev/null
source "${LIB_DIR}/tasks.sh"

main() {
  parse_args "$@"
  normalize_runtime_flags
  dispatch_mode "${MODE}"
}

main "$@"
