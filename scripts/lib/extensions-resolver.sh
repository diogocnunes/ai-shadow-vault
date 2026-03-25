#!/bin/bash

EXTENSIONS_RESOLVER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$EXTENSIONS_RESOLVER_DIR/vault-resolver.sh"
source "$EXTENSIONS_RESOLVER_DIR/core-version.sh"

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

vault_extension_kind() {
    vault_extension_read_field "${1:-}" "KIND" || true
}

vault_extension_is_official_pack() {
    local extension_kind
    extension_kind="$(vault_extension_kind "${1:-}")"
    [ "$extension_kind" = "official-pack" ]
}

vault_extension_is_alias() {
    local extension_kind
    extension_kind="$(vault_extension_kind "${1:-}")"
    [ "$extension_kind" = "alias" ] || [ "$extension_kind" = "legacy-alias" ]
}

vault_extension_alias_target() {
    local extension_name maps_to first_target
    extension_name="$(vault_extension_normalize_name "${1:-}")"
    maps_to="$(vault_extension_read_field "$extension_name" "MAPS_TO" || true)"
    first_target="$(printf '%s\n' "$maps_to" | awk '{print $1}')"
    [ -n "$first_target" ] || return 1
    printf '%s\n' "$first_target"
}

vault_extension_resolve_name() {
    local extension_name target_name
    extension_name="$(vault_extension_normalize_name "${1:-}")"

    if vault_extension_is_alias "$extension_name"; then
        target_name="$(vault_extension_alias_target "$extension_name" || true)"
        if [ -n "$target_name" ]; then
            printf '%s\n' "$target_name"
            return 0
        fi
    fi

    printf '%s\n' "$extension_name"
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

vault_extensions_lockfile() {
    local state_dir
    state_dir="$(vault_extensions_state_dir "${1:-"$PWD"}")"
    printf '%s\n' "$state_dir/lock.json"
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

vault_extension_pack_state_file() {
    local project_root extension_name state_dir
    project_root="${1:-"$PWD"}"
    extension_name="$(vault_extension_normalize_name "${2:-}")"
    state_dir="$(vault_extensions_state_dir "$project_root")"
    printf '%s\n' "$state_dir/pack-${extension_name}.env"
}

vault_extension_write_pack_state() {
    local project_root extension_name pack_name pack_version pack_source pack_path pack_capabilities state_file
    project_root="${1:-"$PWD"}"
    extension_name="$(vault_extension_normalize_name "${2:-}")"
    pack_name="${3:-}"
    pack_version="${4:-}"
    pack_source="${5:-}"
    pack_path="${6:-}"
    pack_capabilities="${7:-}"
    state_file="$(vault_extension_pack_state_file "$project_root" "$extension_name")"

    mkdir -p "$(dirname "$state_file")"
    cat > "$state_file" <<EOF
PACK_NAME=$pack_name
PACK_VERSION=$pack_version
PACK_SOURCE=$pack_source
PACK_PATH=$pack_path
PACK_CAPABILITIES=$pack_capabilities
EOF
}

vault_extension_read_pack_state_field() {
    local project_root extension_name field state_file
    project_root="${1:-"$PWD"}"
    extension_name="$(vault_extension_normalize_name "${2:-}")"
    field="${3:-}"
    state_file="$(vault_extension_pack_state_file "$project_root" "$extension_name")"

    [ -f "$state_file" ] || return 1
    awk -F= -v wanted="$field" '
        $1 == wanted {
            value = substr($0, index($0, "=") + 1)
            print value
            exit
        }
    ' "$state_file"
}

vault_extensions_remove_pack_state() {
    local project_root extension_name state_file
    project_root="${1:-"$PWD"}"
    extension_name="$(vault_extension_normalize_name "${2:-}")"
    state_file="$(vault_extension_pack_state_file "$project_root" "$extension_name")"
    rm -f "$state_file"
}

vault_extensions_write_lockfile() {
    local project_root lockfile core_version first_entry
    local extension_name pack_name pack_version pack_source pack_path pack_capabilities old_ifs
    local cap_item cap_first
    project_root="${1:-"$PWD"}"
    lockfile="$(vault_extensions_lockfile "$project_root")"
    core_version="$(vault_core_version)"

    mkdir -p "$(dirname "$lockfile")"

    {
        echo "{"
        echo "  \"schema_version\": 1,"
        echo "  \"core_version\": \"$core_version\","
        echo "  \"packs\": {"

        first_entry=1
        while IFS= read -r extension_name; do
            [ -n "$extension_name" ] || continue
            vault_extension_is_official_pack "$extension_name" || continue

            pack_name="$(vault_extension_read_pack_state_field "$project_root" "$extension_name" "PACK_NAME" || true)"
            pack_version="$(vault_extension_read_pack_state_field "$project_root" "$extension_name" "PACK_VERSION" || true)"
            pack_source="$(vault_extension_read_pack_state_field "$project_root" "$extension_name" "PACK_SOURCE" || true)"
            pack_path="$(vault_extension_read_pack_state_field "$project_root" "$extension_name" "PACK_PATH" || true)"
            pack_capabilities="$(vault_extension_read_pack_state_field "$project_root" "$extension_name" "PACK_CAPABILITIES" || true)"

            [ -n "$pack_name" ] || continue
            [ -n "$pack_version" ] || continue
            [ -n "$pack_path" ] || continue

            if [ "$first_entry" -eq 0 ]; then
                echo ","
            fi
            first_entry=0

            printf '    "%s": {\n' "$extension_name"
            printf '      "name": "%s",\n' "$pack_name"
            printf '      "version": "%s",\n' "$pack_version"
            printf '      "source": "%s",\n' "$pack_source"
            printf '      "path": "%s",\n' "$pack_path"
            printf '      "capabilities": ['
            cap_first=1
            old_ifs="$IFS"
            IFS=','
            for cap_item in $pack_capabilities; do
                if [ "$cap_first" -eq 0 ]; then
                    printf ', '
                fi
                cap_first=0
                printf '"%s"' "$cap_item"
            done
            IFS="$old_ifs"
            if [ "$cap_first" -eq 1 ]; then
                printf '"skills"'
            fi
            printf ']\n'
            printf '    }'
        done < <(vault_extensions_load_enabled "$project_root")

        if [ "$first_entry" -eq 1 ]; then
            echo "    "
        else
            echo
        fi

        echo "  }"
        echo "}"
    } > "$lockfile"
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
