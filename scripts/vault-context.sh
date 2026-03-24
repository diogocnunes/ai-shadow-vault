#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
    cat <<'USAGE'
Usage:
  vault-context refresh
  vault-context trim
USAGE
}

subcommand="${1:-refresh}"

case "$subcommand" in
    refresh)
        "$SCRIPT_DIR/vault-ai-context-file.sh"
        ;;
    trim)
        if [[ -x "$SCRIPT_DIR/vault-doctor.sh" ]]; then
            "$SCRIPT_DIR/vault-doctor.sh" --check inflation --fix
        else
            echo "vault-doctor not found." >&2
            exit 1
        fi
        ;;
    -h|--help|help)
        usage
        ;;
    *)
        echo "Unknown subcommand: $subcommand" >&2
        usage
        exit 1
        ;;
esac
