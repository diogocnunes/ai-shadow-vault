#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/pack-contract.sh"

usage() {
    cat <<'EOF_USAGE'
Usage:
  vault-pack validate <pack-dir>
EOF_USAGE
}

validate_cmd() {
    local pack_dir="${1:-}"
    if [[ -z "$pack_dir" ]]; then
        echo "Provide a pack directory." >&2
        usage
        exit 1
    fi

    vault_pack_validate_manifest_schema "$pack_dir"
    echo "Pack manifest is valid: $pack_dir"
}

main() {
    local command="${1:-}"
    shift || true

    case "$command" in
        validate)
            validate_cmd "$@"
            ;;
        ""|-h|--help|help)
            usage
            ;;
        *)
            echo "Unknown command: $command" >&2
            usage
            exit 1
            ;;
    esac
}

main "$@"
