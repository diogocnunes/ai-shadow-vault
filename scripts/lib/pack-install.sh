#!/bin/bash

set -euo pipefail

PACK_INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$PACK_INSTALL_DIR/extensions-resolver.sh"
source "$PACK_INSTALL_DIR/pack-contract.sh"

vault_pack_install_extension() {
    local project_root="${1:-$PWD}"
    local extension_name source_url default_ref pack_state_path existing_path
    local data_root temp_dir pack_name pack_version pack_capabilities install_path

    extension_name="$(vault_extension_normalize_name "${2:-}")"
    [ -n "$extension_name" ] || {
        echo "ASV-PACK-INSTALL-001: Missing extension name" >&2
        return 1
    }

    if ! vault_extension_is_official_pack "$extension_name"; then
        return 0
    fi

    source_url="$(vault_extension_read_field "$extension_name" "SOURCE_URL" || true)"
    default_ref="$(vault_extension_read_field "$extension_name" "DEFAULT_REF" || true)"
    [ -n "$default_ref" ] || default_ref="main"

    [ -n "$source_url" ] || {
        echo "ASV-PACK-INSTALL-002: Extension '$extension_name' has no SOURCE_URL configured" >&2
        return 1
    }

    existing_path="$(vault_extension_read_pack_state_field "$project_root" "$extension_name" "PACK_PATH" || true)"
    if [[ -n "$existing_path" && -f "$existing_path/pack.json" ]]; then
        vault_pack_assert_core_compat "$existing_path" || return 1
        printf '%s\n' "$existing_path"
        return 0
    fi

    data_root="$(vault_ensure_data_root)"
    mkdir -p "$data_root/packs"

    temp_dir="$data_root/packs/.tmp-${extension_name}-$$"
    rm -rf "$temp_dir"

    if ! git clone --depth 1 --branch "$default_ref" "$source_url" "$temp_dir" >/dev/null 2>&1; then
        rm -rf "$temp_dir"
        echo "ASV-PACK-INSTALL-003: Failed to clone '$source_url' (ref: $default_ref) for extension '$extension_name'" >&2
        return 1
    fi

    vault_pack_assert_core_compat "$temp_dir" || {
        rm -rf "$temp_dir"
        return 1
    }

    pack_name="$(vault_pack_read_string_field "$temp_dir" "name")"
    pack_version="$(vault_pack_read_string_field "$temp_dir" "version")"
    pack_capabilities="$(vault_pack_read_capabilities "$temp_dir" | paste -sd ',' -)"

    install_path="$data_root/packs/$pack_name/$pack_version"
    mkdir -p "$(dirname "$install_path")"
    rm -rf "$install_path"
    mv "$temp_dir" "$install_path"

    vault_extension_write_pack_state \
        "$project_root" \
        "$extension_name" \
        "$pack_name" \
        "$pack_version" \
        "$source_url" \
        "$install_path" \
        "$pack_capabilities"

    printf '%s\n' "$install_path"
}
