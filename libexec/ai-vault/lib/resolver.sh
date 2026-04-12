#!/bin/bash

vault_primary_data_root() {
    if [[ -n "${AI_VAULT_BASE_PATH:-}" ]]; then
        printf '%s\n' "$AI_VAULT_BASE_PATH"
        return
    fi

    printf '%s\n' "$HOME/.ai-shadow-vault-data"
}

vault_legacy_data_root() {
    printf '%s\n' "$HOME/.gemini-vault"
}

vault_realpath() {
    local target="$1"

    if command -v python3 >/dev/null 2>&1; then
        python3 - "$target" <<'PY'
import os
import sys

print(os.path.realpath(sys.argv[1]))
PY
        return
    fi

    if command -v realpath >/dev/null 2>&1; then
        realpath "$target"
        return
    fi

    (
        cd "$(dirname "$target")" >/dev/null 2>&1 || exit 1
        printf '%s/%s\n' "$(pwd -P)" "$(basename "$target")"
    )
}

vault_git_toplevel() {
    local start_dir="${1:-$PWD}"
    git -C "$start_dir" rev-parse --show-toplevel 2>/dev/null
}

vault_git_common_root() {
    local start_dir="${1:-$PWD}"
    local common_dir

    common_dir="$(git -C "$start_dir" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" || return 1
    dirname "$common_dir"
}

vault_resolve_project_root() {
    local start_dir="${1:-$PWD}"
    local git_root current_dir

    git_root="$(vault_git_toplevel "$start_dir")"
    if [[ -n "$git_root" ]]; then
        printf '%s\n' "$git_root"
        return
    fi

    current_dir="$start_dir"
    while [[ "$current_dir" != "/" ]]; do
        if [[ -d "$current_dir/.git" || -f "$current_dir/composer.json" || -f "$current_dir/package.json" ]]; then
            printf '%s\n' "$current_dir"
            return
        fi
        current_dir="$(dirname "$current_dir")"
    done

    printf '%s\n' "$start_dir"
}

vault_resolve_identity_root() {
    local project_root="${1:-$PWD}"
    local common_root

    common_root="$(vault_git_common_root "$project_root" 2>/dev/null || true)"
    if [[ -n "$common_root" ]]; then
        vault_realpath "$common_root"
        return
    fi

    vault_realpath "$(vault_resolve_project_root "$project_root")"
}

vault_slugify() {
    local value="$1"
    printf '%s' "$value" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//; s/-{2,}/-/g'
}

vault_resolve_project_slug() {
    local identity_root
    identity_root="$(vault_resolve_identity_root "${1:-$PWD}")"
    vault_slugify "$(basename "$identity_root")"
}

vault_sha1() {
    local value="$1"

    if command -v shasum >/dev/null 2>&1; then
        printf '%s' "$value" | shasum | awk '{print $1}'
        return
    fi
    if command -v sha1sum >/dev/null 2>&1; then
        printf '%s' "$value" | sha1sum | awk '{print $1}'
        return
    fi
    if command -v openssl >/dev/null 2>&1; then
        printf '%s' "$value" | openssl sha1 | awk '{print $NF}'
        return
    fi

    echo "No SHA1 implementation available." >&2
    exit 1
}

vault_resolve_identity_hash() {
    local identity_root
    identity_root="$(vault_resolve_identity_root "${1:-$PWD}")"
    vault_sha1 "$identity_root" | cut -c1-8
}

vault_resolve_project_vault() {
    local start_dir="${1:-$PWD}"
    local base_path="${2:-${AI_VAULT_BASE_PATH:-$(vault_primary_data_root)}}"
    local project_slug hash

    project_slug="$(vault_resolve_project_slug "$start_dir")"
    hash="$(vault_resolve_identity_hash "$start_dir")"
    printf '%s/%s-%s\n' "$base_path" "$project_slug" "$hash"
}

vault_resolve_existing_project_vault() {
    local start_dir="${1:-$PWD}"
    local base_path="${2:-${AI_VAULT_BASE_PATH:-$(vault_primary_data_root)}}"
    local primary legacy slug identity_hash

    primary="$(vault_resolve_project_vault "$start_dir" "$base_path")"
    if [[ -d "$primary" ]]; then
        printf '%s\n' "$primary"
        return
    fi

    slug="$(vault_resolve_project_slug "$start_dir")"
    identity_hash="$(vault_resolve_identity_hash "$start_dir")"
    legacy="$(vault_legacy_data_root)/$slug"
    if [[ -d "$legacy" ]]; then
        printf '%s\n' "$legacy"
        return
    fi

    legacy="$(vault_legacy_data_root)/$slug-$identity_hash"
    if [[ -d "$legacy" ]]; then
        printf '%s\n' "$legacy"
        return
    fi

    printf '%s\n' "$primary"
}

vault_is_inside_data_root() {
    local target_path="$1"
    local primary_root legacy_root

    primary_root="$(vault_primary_data_root)"
    legacy_root="$(vault_legacy_data_root)"

    case "$target_path" in
        "$primary_root"|"$primary_root"/*|"$legacy_root"|"$legacy_root"/*)
            return 0
            ;;
    esac

    return 1
}
