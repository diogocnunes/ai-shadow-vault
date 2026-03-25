#!/bin/bash

set -euo pipefail

CORE_VERSION_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

vault_core_version_file() {
    printf '%s\n' "$(cd "$CORE_VERSION_LIB_DIR/../.." && pwd)/VERSION"
}

vault_core_version() {
    local version_file
    version_file="$(vault_core_version_file)"
    if [[ ! -f "$version_file" ]]; then
        echo "0.0.0"
        return 0
    fi

    sed -n '1p' "$version_file" | tr -d '[:space:]'
}
