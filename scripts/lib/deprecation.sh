#!/bin/bash

set -euo pipefail

DEPRECATION_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPRECATION_EMITTED_KEYS=""
source "$DEPRECATION_LIB_DIR/migration-notices.sh"

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

asv_warn_once() {
    local key="${1:-}"
    local message="${2:-}"
    local marker_file="${ASV_WARN_MARKER_FILE:-}"

    if printf '%s\n' "$DEPRECATION_EMITTED_KEYS" | grep -qx "$key"; then
        return 0
    fi

    if [[ -n "$marker_file" ]]; then
        mkdir -p "$(dirname "$marker_file")" >/dev/null 2>&1 || true
        touch "$marker_file" >/dev/null 2>&1 || true
        if grep -qx "$key" "$marker_file" 2>/dev/null; then
            return 0
        fi
        printf '%s\n' "$key" >> "$marker_file" 2>/dev/null || true
    fi

    DEPRECATION_EMITTED_KEYS="${DEPRECATION_EMITTED_KEYS}${DEPRECATION_EMITTED_KEYS:+$'\n'}$key"
    printf '%s\n' "$message" >&2
}

asv_warn_soft_migration_for_pack() {
    local pack_name="${1:-}"
    local soft_notice

    soft_notice="$(asv_soft_migration_notice_for_pack "$pack_name" || true)"
    [[ -n "$soft_notice" ]] || return 0

    asv_warn_once "ASV-SOFT-MIGRATION-001:$pack_name" "$soft_notice"
}

asv_warn_skill_legacy_fallback() {
    local skill_id="${1:-}"
    local pack_name="${2:-}"
    asv_warn_once \
        "ASV-DEPRECATION-SKILL-001:$skill_id" \
        "ASV-DEPRECATION-SKILL-001: Skill '$skill_id' moved to pack '$pack_name'. Legacy fallback used. Run: vault-ext enable $pack_name"
    asv_warn_soft_migration_for_pack "$pack_name"
}
