#!/bin/bash

set -euo pipefail

DEPRECATION_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

asv_deprecation_map_file() {
    printf '%s\n' "$(cd "$DEPRECATION_LIB_DIR/../.." && pwd)/config/deprecations/skills-to-pack.json"
}

asv_deprecation_pack_for_skill() {
    local skill_id="${1:-}"
    local map_file

    map_file="$(asv_deprecation_map_file)"
    [[ -f "$map_file" ]] || return 1

    awk -F'"' -v wanted="$skill_id" '$2 == wanted { print $4; exit }' "$map_file"
}

asv_error_skill_pack_required() {
    local skill_id="${1:-}"
    local pack_name="${2:-}"
    echo "ASV-HARD-MIGRATION-001: Skill '$skill_id' is no longer provided by core. Install required pack '$pack_name' with: vault-ext enable $pack_name" >&2
}
