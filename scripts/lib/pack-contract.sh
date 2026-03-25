#!/bin/bash

set -euo pipefail

PACK_CONTRACT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$PACK_CONTRACT_DIR/core-version.sh"

vault_pack_manifest_path() {
    local pack_dir="${1:-}"
    printf '%s\n' "$pack_dir/pack.json"
}

vault_pack_manifest_exists() {
    local manifest_path
    manifest_path="$(vault_pack_manifest_path "${1:-}")"
    [[ -f "$manifest_path" ]]
}

vault_pack_manifest_is_valid_json() {
    local manifest_path
    manifest_path="$(vault_pack_manifest_path "${1:-}")"

    if command -v python3 >/dev/null 2>&1; then
        python3 -m json.tool "$manifest_path" >/dev/null 2>&1
        return $?
    fi

    # Minimal fallback when python3 is unavailable.
    grep -q '{' "$manifest_path" && grep -q '}' "$manifest_path"
}

vault_pack_manifest_compact() {
    local manifest_path
    manifest_path="$(vault_pack_manifest_path "${1:-}")"
    tr -d '\n\r' < "$manifest_path"
}

vault_pack_read_string_field() {
    local pack_dir="${1:-}"
    local field="${2:-}"
    local compact value

    compact="$(vault_pack_manifest_compact "$pack_dir")"
    value="$(printf '%s' "$compact" | sed -nE "s/.*\"$field\"[[:space:]]*:[[:space:]]*\"([^\"]+)\".*/\\1/p" | head -n 1)"
    [[ -n "$value" ]] || return 1
    printf '%s\n' "$value"
}

vault_pack_read_capabilities() {
    local pack_dir="${1:-}"
    local compact raw

    compact="$(vault_pack_manifest_compact "$pack_dir")"
    raw="$(printf '%s' "$compact" | sed -nE 's/.*"capabilities"[[:space:]]*:[[:space:]]*\[([^]]*)\].*/\1/p' | head -n 1)"
    [[ -n "$raw" ]] || return 1

    printf '%s\n' "$raw" \
        | tr ',' '\n' \
        | sed -E 's/^[[:space:]]*"?//; s/"?[[:space:]]*$//' \
        | sed '/^[[:space:]]*$/d'
}

vault_pack_is_valid_semver() {
    [[ "${1:-}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

vault_pack_compare_semver() {
    local left="${1:-}"
    local right="${2:-}"

    if [[ "$left" == "$right" ]]; then
        echo 0
        return 0
    fi

    if [[ "$(printf '%s\n%s\n' "$left" "$right" | sort -V | head -n 1)" == "$left" ]]; then
        echo -1
    else
        echo 1
    fi
}

vault_pack_check_constraint() {
    local version="${1:-}"
    local op="${2:-}"
    local target="${3:-}"
    local cmp

    cmp="$(vault_pack_compare_semver "$version" "$target")"

    case "$op" in
        '>') [[ "$cmp" -gt 0 ]] ;;
        '>=') [[ "$cmp" -ge 0 ]] ;;
        '<') [[ "$cmp" -lt 0 ]] ;;
        '<=') [[ "$cmp" -le 0 ]] ;;
        '=') [[ "$cmp" -eq 0 ]] ;;
        *) return 1 ;;
    esac
}

vault_pack_core_api_range_is_valid() {
    local range="${1:-}"
    local token op version

    [[ -n "$range" ]] || return 1

    for token in $range; do
        op=""
        version=""

        if [[ "$token" =~ ^(>=|<=|>|<|=)([0-9]+\.[0-9]+\.[0-9]+)$ ]]; then
            op="${BASH_REMATCH[1]}"
            version="${BASH_REMATCH[2]}"
        elif [[ "$token" =~ ^([0-9]+\.[0-9]+\.[0-9]+)$ ]]; then
            op="="
            version="${BASH_REMATCH[1]}"
        else
            return 1
        fi

        vault_pack_is_valid_semver "$version" || return 1
    done

    return 0
}

vault_pack_version_satisfies_core_api() {
    local version="${1:-}"
    local range="${2:-}"
    local token op target

    vault_pack_is_valid_semver "$version" || return 1
    vault_pack_core_api_range_is_valid "$range" || return 1

    for token in $range; do
        if [[ "$token" =~ ^(>=|<=|>|<|=)([0-9]+\.[0-9]+\.[0-9]+)$ ]]; then
            op="${BASH_REMATCH[1]}"
            target="${BASH_REMATCH[2]}"
        else
            op="="
            target="$token"
        fi

        vault_pack_check_constraint "$version" "$op" "$target" || return 1
    done

    return 0
}

vault_pack_validate_manifest_schema() {
    local pack_dir="${1:-}"
    local name version description core_api capabilities_count

    vault_pack_manifest_exists "$pack_dir" || {
        echo "ASV-PACK-VALIDATE-001: Missing pack manifest at $(vault_pack_manifest_path "$pack_dir")" >&2
        return 1
    }

    vault_pack_manifest_is_valid_json "$pack_dir" || {
        echo "ASV-PACK-VALIDATE-002: Invalid JSON in $(vault_pack_manifest_path "$pack_dir")" >&2
        return 1
    }

    name="$(vault_pack_read_string_field "$pack_dir" "name" || true)"
    version="$(vault_pack_read_string_field "$pack_dir" "version" || true)"
    description="$(vault_pack_read_string_field "$pack_dir" "description" || true)"
    core_api="$(vault_pack_read_string_field "$pack_dir" "core_api" || true)"

    [[ -n "$name" ]] || { echo "ASV-PACK-VALIDATE-003: Missing required field 'name'" >&2; return 1; }
    [[ -n "$version" ]] || { echo "ASV-PACK-VALIDATE-004: Missing required field 'version'" >&2; return 1; }
    [[ -n "$description" ]] || { echo "ASV-PACK-VALIDATE-005: Missing required field 'description'" >&2; return 1; }
    [[ -n "$core_api" ]] || { echo "ASV-PACK-VALIDATE-006: Missing required field 'core_api'" >&2; return 1; }

    vault_pack_is_valid_semver "$version" || {
        echo "ASV-PACK-VALIDATE-007: Field 'version' must be semver (x.y.z). Got: $version" >&2
        return 1
    }

    vault_pack_core_api_range_is_valid "$core_api" || {
        echo "ASV-PACK-VALIDATE-008: Field 'core_api' has invalid range syntax. Got: $core_api" >&2
        return 1
    }

    capabilities_count="$(vault_pack_read_capabilities "$pack_dir" 2>/dev/null | wc -l | tr -d '[:space:]')"
    if [[ -z "$capabilities_count" || "$capabilities_count" -eq 0 ]]; then
        echo "ASV-PACK-VALIDATE-009: Field 'capabilities' must be a non-empty array" >&2
        return 1
    fi

    return 0
}

vault_pack_assert_core_compat() {
    local pack_dir="${1:-}"
    local pack_name pack_version core_api core_version

    vault_pack_validate_manifest_schema "$pack_dir" || return 1

    pack_name="$(vault_pack_read_string_field "$pack_dir" "name")"
    pack_version="$(vault_pack_read_string_field "$pack_dir" "version")"
    core_api="$(vault_pack_read_string_field "$pack_dir" "core_api")"
    core_version="$(vault_core_version)"

    if ! vault_pack_version_satisfies_core_api "$core_version" "$core_api"; then
        echo "ASV-COMPAT-001: Pack '$pack_name@$pack_version' requires core_api '$core_api'; current core is '$core_version'." >&2
        return 1
    fi

    return 0
}
