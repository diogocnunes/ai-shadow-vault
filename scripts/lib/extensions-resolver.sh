#!/bin/sh

EXTENSIONS_RESOLVER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$EXTENSIONS_RESOLVER_DIR/vault-resolver.sh"

vault_extensions_catalog_root() {
    local script_root
    script_root="$(cd "$EXTENSIONS_RESOLVER_DIR/../.." && pwd)"
    printf '%s\n' "$script_root/extensions"
}

vault_extension_normalize_name() {
    printf '%s\n' "${1:-}" \
        | tr '[:upper:]' '[:lower:]' \
        | sed -E 's/[ _]+/-/g; s/[^a-z0-9-]//g; s/^-+//; s/-+$//; s/-+/-/g'
}

vault_extension_manifest_path() {
    local extension_name
    extension_name="$(vault_extension_normalize_name "${1:-}")"
    printf '%s\n' "$(vault_extensions_catalog_root)/$extension_name/extension.env"
}

vault_extension_exists() {
    [ -f "$(vault_extension_manifest_path "${1:-}")" ]
}

vault_extension_read_field() {
    local extension_name field manifest_path
    extension_name="${1:-}"
    field="${2:-}"
    manifest_path="$(vault_extension_manifest_path "$extension_name")"
    [ -f "$manifest_path" ] || return 1
    awk -F= -v wanted="$field" '
        $1 == wanted {
            value = substr($0, index($0, "=") + 1)
            gsub(/^"/, "", value)
            gsub(/"$/, "", value)
            print value
            exit
        }
    ' "$manifest_path"
}

vault_extensions_discover() {
    local catalog_root manifest_path extension_name extension_desc
    catalog_root="$(vault_extensions_catalog_root)"

    find "$catalog_root" -mindepth 2 -maxdepth 2 -name extension.env | sort | while IFS= read -r manifest_path; do
        extension_name="$(vault_extension_read_field "$(basename "$(dirname "$manifest_path")")" "NAME" || true)"
        extension_desc="$(vault_extension_read_field "$(basename "$(dirname "$manifest_path")")" "DESCRIPTION" || true)"
        if [ -z "$extension_name" ]; then
            extension_name="$(basename "$(dirname "$manifest_path")")"
        fi
        printf '%s\t%s\n' "$extension_name" "$extension_desc"
    done
}

vault_extensions_project_root() {
    vault_resolve_project_root "${1:-"$PWD"}"
}

vault_extensions_state_dir() {
    local project_root
    project_root="$(vault_extensions_project_root "${1:-"$PWD"}")"
    printf '%s\n' "$project_root/.ai/extensions"
}

vault_extensions_enabled_file() {
    local state_dir
    state_dir="$(vault_extensions_state_dir "${1:-"$PWD"}")"
    printf '%s\n' "$state_dir/enabled.txt"
}

vault_extensions_ensure_state_dir() {
    local state_dir
    state_dir="$(vault_extensions_state_dir "${1:-"$PWD"}")"
    mkdir -p "$state_dir"
    printf '%s\n' "$state_dir"
}

vault_extensions_load_enabled() {
    local enabled_file
    enabled_file="$(vault_extensions_enabled_file "${1:-"$PWD"}")"
    if [ -f "$enabled_file" ]; then
        grep -v '^[[:space:]]*$' "$enabled_file" | grep -v '^#' || true
    fi
}

vault_extension_is_enabled() {
    local project_root extension_name enabled_item
    project_root="${1:-"$PWD"}"
    extension_name="$(vault_extension_normalize_name "${2:-}")"

    while IFS= read -r enabled_item; do
        [ "$enabled_item" = "$extension_name" ] && return 0
    done < <(vault_extensions_load_enabled "$project_root")

    return 1
}

vault_extensions_write_enabled() {
    local project_root enabled_file item
    project_root="${1:-"$PWD"}"
    shift || true
    enabled_file="$(vault_extensions_enabled_file "$project_root")"
    mkdir -p "$(dirname "$enabled_file")"
    : > "$enabled_file"
    for item in "$@"; do
        [ -n "$item" ] && printf '%s\n' "$item" >> "$enabled_file"
    done
}

vault_extension_hook_script() {
    local extension_name hook_name
    extension_name="$(vault_extension_normalize_name "${1:-}")"
    hook_name="${2:-}"
    printf '%s\n' "$(vault_extensions_catalog_root)/$extension_name/hooks/$hook_name.sh"
}

vault_extension_run_hook() {
    local project_root extension_name hook_name hook_script
    project_root="${1:-"$PWD"}"
    extension_name="${2:-}"
    hook_name="${3:-}"
    hook_script="$(vault_extension_hook_script "$extension_name" "$hook_name")"

    [ -x "$hook_script" ] || return 0

    AI_SHADOW_PROJECT_ROOT="$project_root" "$hook_script"
}

vault_extension_notice_if_disabled() {
    local project_root extension_name command_name
    project_root="${1:-"$PWD"}"
    extension_name="$(vault_extension_normalize_name "${2:-}")"
    command_name="${3:-$extension_name}"

    if vault_extension_is_enabled "$project_root" "$extension_name"; then
        return 0
    fi

    printf 'Note: `%s` is now treated as an optional workflow. Enable it with `vault-ext enable %s` for this project.\n' \
        "$command_name" "$extension_name" >&2
}
