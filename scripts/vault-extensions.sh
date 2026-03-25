#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/extensions-resolver.sh"
source "$SCRIPT_DIR/lib/pack-install.sh"

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

PROJECT_ROOT="$(vault_extensions_project_root "$PWD")"

dedupe_lines() {
    awk '!seen[$0]++'
}

list_available() {
    echo -e "${BLUE}Available extensions${NC}"
    vault_extensions_discover | while IFS=$'\t' read -r extension_name extension_desc; do
        local extension_kind
        extension_kind="$(vault_extension_read_field "$extension_name" "KIND" || true)"
        if [[ -n "$extension_kind" ]]; then
            printf '  %-22s %-9s %s\n' "$extension_name" "[$extension_kind]" "$extension_desc"
        else
            printf '  %-22s %s\n' "$extension_name" "$extension_desc"
        fi
    done
}

show_extension_info() {
    local extension_name source_url upstream kind maps_to
    extension_name="$(vault_extension_normalize_name "${1:-}")"

    validate_extensions "$extension_name"

    source_url="$(vault_extension_read_field "$extension_name" "SOURCE_URL" || true)"
    upstream="$(vault_extension_read_field "$extension_name" "UPSTREAM" || true)"
    kind="$(vault_extension_read_field "$extension_name" "KIND" || true)"
    maps_to="$(vault_extension_read_field "$extension_name" "MAPS_TO" || true)"

    echo -e "${BLUE}Extension:${NC} $extension_name"
    echo "Description: $(vault_extension_read_field "$extension_name" "DESCRIPTION" || true)"
    [[ -n "$kind" ]] && echo "Kind: $kind"
    [[ -n "$upstream" ]] && echo "Upstream: $upstream"
    [[ -n "$source_url" ]] && echo "Source: $source_url"
    [[ -n "$maps_to" ]] && echo "Related local workflow: $maps_to"
}

status_extensions() {
    local enabled=()
    local item

    while IFS= read -r item; do
        [[ -n "$item" ]] && enabled+=("$item")
    done < <(vault_extensions_load_enabled "$PROJECT_ROOT")

    echo -e "${BLUE}AI Shadow Vault Extensions${NC}"
    echo "Project Root: $PROJECT_ROOT"
    echo
    if [[ "${#enabled[@]}" -eq 0 ]]; then
        echo "Enabled: none"
        return
    fi

    echo "Enabled:"
    for item in "${enabled[@]}"; do
        echo "  - $item"
    done
}

validate_extensions() {
    local extension_name
    for extension_name in "$@"; do
        if ! vault_extension_exists "$extension_name"; then
            echo -e "${RED}Unknown extension:${NC} $extension_name" >&2
            exit 1
        fi
    done
}

enable_extensions() {
    local existing=()
    local requested=()
    local merged=()
    local item

    validate_extensions "$@"
    vault_extensions_ensure_state_dir "$PROJECT_ROOT" >/dev/null

    while IFS= read -r item; do
        [[ -n "$item" ]] && existing+=("$item")
    done < <(vault_extensions_load_enabled "$PROJECT_ROOT")

    for item in "$@"; do
        requested+=("$(vault_extension_normalize_name "$item")")
    done

    while IFS= read -r item; do
        [[ -n "$item" ]] && merged+=("$item")
    done < <(printf '%s\n' "${existing[@]+"${existing[@]}"}" "${requested[@]+"${requested[@]}"}" | dedupe_lines)

    vault_extensions_write_enabled "$PROJECT_ROOT" "${merged[@]}"

    for item in "${requested[@]}"; do
        if vault_extension_is_official_pack "$item"; then
            vault_pack_install_extension "$PROJECT_ROOT" "$item" >/dev/null
        fi
        vault_extension_run_hook "$PROJECT_ROOT" "$item" enable
        vault_extension_run_hook "$PROJECT_ROOT" "$item" sync
    done

    vault_extensions_write_lockfile "$PROJECT_ROOT"
    echo -e "${GREEN}Enabled extensions:${NC} ${requested[*]}"
}

disable_extensions() {
    local keep=()
    local to_disable=()
    local item

    validate_extensions "$@"

    for item in "$@"; do
        to_disable+=("$(vault_extension_normalize_name "$item")")
    done

    while IFS= read -r item; do
        [[ -n "$item" ]] || continue
        if printf '%s\n' "${to_disable[@]}" | grep -qx "$item"; then
            vault_extension_run_hook "$PROJECT_ROOT" "$item" disable
            vault_extensions_remove_pack_state "$PROJECT_ROOT" "$item"
            continue
        fi
        keep+=("$item")
    done < <(vault_extensions_load_enabled "$PROJECT_ROOT")

    vault_extensions_write_enabled "$PROJECT_ROOT" "${keep[@]+"${keep[@]}"}"
    vault_extensions_write_lockfile "$PROJECT_ROOT"
    echo -e "${GREEN}Disabled extensions:${NC} ${to_disable[*]}"
}

sync_extensions() {
    local targets=()
    local item

    if [[ "$#" -gt 0 ]]; then
        validate_extensions "$@"
        for item in "$@"; do
            targets+=("$(vault_extension_normalize_name "$item")")
        done
    else
        while IFS= read -r item; do
            [[ -n "$item" ]] && targets+=("$item")
        done < <(vault_extensions_load_enabled "$PROJECT_ROOT")
    fi

    for item in "${targets[@]}"; do
        if vault_extension_is_official_pack "$item"; then
            vault_pack_install_extension "$PROJECT_ROOT" "$item" >/dev/null
        fi
        vault_extension_run_hook "$PROJECT_ROOT" "$item" sync
    done

    if [[ "${#targets[@]}" -eq 0 ]]; then
        echo -e "${YELLOW}No enabled extensions to sync.${NC}"
        vault_extensions_write_lockfile "$PROJECT_ROOT"
        return
    fi

    vault_extensions_write_lockfile "$PROJECT_ROOT"
    echo -e "${GREEN}Synced extensions:${NC} ${targets[*]}"
}

run_hook_for_enabled() {
    local hook_name="$1"
    local item

    while IFS= read -r item; do
        [[ -n "$item" ]] || continue
        vault_extension_run_hook "$PROJECT_ROOT" "$item" "$hook_name"
    done < <(vault_extensions_load_enabled "$PROJECT_ROOT")
}

usage() {
    cat <<EOF
Usage:
  vault-ext list
  vault-ext info <extension>
  vault-ext status
  vault-ext enable <extension> [extension...]
  vault-ext disable <extension> [extension...]
  vault-ext sync [extension...]
  vault-ext run-hook <hook>
EOF
}

main() {
    local command="${1:-status}"
    shift || true

    case "$command" in
        list)
            list_available
            ;;
        info)
            [[ "$#" -gt 0 ]] || { echo -e "${RED}Provide an extension name.${NC}" >&2; exit 1; }
            show_extension_info "$1"
            ;;
        status)
            status_extensions
            ;;
        enable)
            [[ "$#" -gt 0 ]] || { echo -e "${RED}Provide at least one extension.${NC}" >&2; exit 1; }
            enable_extensions "$@"
            ;;
        disable)
            [[ "$#" -gt 0 ]] || { echo -e "${RED}Provide at least one extension.${NC}" >&2; exit 1; }
            disable_extensions "$@"
            ;;
        sync)
            sync_extensions "$@"
            ;;
        run-hook)
            [[ "$#" -gt 0 ]] || { echo -e "${RED}Provide a hook name.${NC}" >&2; exit 1; }
            run_hook_for_enabled "$1"
            ;;
        *)
            usage
            exit 1
            ;;
    esac
}

main "$@"
