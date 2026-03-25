#!/bin/bash

set -euo pipefail

MIGRATION_NOTICE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

asv_migration_config_file_for_pack() {
    local pack="$(printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]')"
    printf '%s\n' "$(cd "$MIGRATION_NOTICE_DIR/../.." && pwd)/config/migration/${pack}-soft-migration.env"
}

asv_migration_read_field_for_pack() {
    local pack="${1:-}"
    local field="${2:-}"
    local config_file

    config_file="$(asv_migration_config_file_for_pack "$pack")"
    [[ -f "$config_file" ]] || return 1

    awk -F= -v wanted="$field" '
        $1 == wanted {
            value = substr($0, index($0, "=") + 1)
            gsub(/^"/, "", value)
            gsub(/"$/, "", value)
            print value
            exit
        }
    ' "$config_file"
}

asv_soft_migration_notice_for_pack() {
    local pack="$(printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]')"
    local start_date fallback_until install_command

    start_date="$(asv_migration_read_field_for_pack "$pack" "START_DATE" || true)"
    fallback_until="$(asv_migration_read_field_for_pack "$pack" "FALLBACK_GUARANTEED_UNTIL" || true)"
    install_command="$(asv_migration_read_field_for_pack "$pack" "INSTALL_COMMAND" || true)"

    [[ -n "$start_date" && -n "$fallback_until" && -n "$install_command" ]] || return 1

    printf '%s\n' "ASV-SOFT-MIGRATION-001: '$pack' pack soft migration active since $start_date. Legacy fallback is guaranteed until $fallback_until. Install with: $install_command"
}
