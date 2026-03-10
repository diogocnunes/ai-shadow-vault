#!/bin/bash

set -euo pipefail

SKILLS_RESOLVER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SKILLS_RESOLVER_DIR/vault-resolver.sh"

skills_catalog_root() {
    local script_root
    script_root="$(cd "$SKILLS_RESOLVER_DIR/../.." && pwd)"
    printf '%s\n' "$script_root/templates/Skills"
}

skills_normalize_name() {
    local raw_name
    raw_name="${1:-}"

    printf '%s\n' "$raw_name" \
        | tr '[:upper:]' '[:lower:]' \
        | sed -E 's/[ _]+/-/g; s/[^a-z0-9-]//g; s/^-+//; s/-+$//; s/-+/-/g'
}

skills_read_frontmatter() {
    local skill_file field
    skill_file=$1
    field=$2

    awk -v wanted="$field" '
        BEGIN { in_fm = 0 }
        NR == 1 && $0 == "---" { in_fm = 1; next }
        in_fm && $0 == "---" { exit }
        in_fm && $0 ~ ("^" wanted ":") {
            sub("^[^:]+:[[:space:]]*", "", $0)
            gsub(/^["'\''"]|["'\''"]$/, "", $0)
            print
            exit
        }
    ' "$skill_file"
}

skills_strip_frontmatter() {
    local skill_file
    skill_file=$1

    if head -n 1 "$skill_file" | grep -q '^---$'; then
        awk '
            BEGIN { in_fm = 0; seen = 0 }
            NR == 1 && $0 == "---" { in_fm = 1; next }
            in_fm && $0 == "---" { in_fm = 0; seen = 1; next }
            !in_fm { print }
        ' "$skill_file"
        return
    fi

    cat "$skill_file"
}

skills_is_installable_file() {
    local skill_file basename_file
    skill_file=$1
    basename_file="$(basename "$skill_file")"

    case "$skill_file" in
        */Laravel/*)
            return 1
            ;;
    esac

    case "$basename_file" in
        LICENSE|CREDITS.md)
            return 1
            ;;
    esac

    return 0
}

skills_discover() {
    local skills_root skill_file skill_name skill_desc normalized_name
    skills_root="$(skills_catalog_root)"

    find "$skills_root" -type f -name "*.md" | sort | while IFS= read -r skill_file; do
        skills_is_installable_file "$skill_file" || continue

        skill_name="$(skills_read_frontmatter "$skill_file" "name" || true)"
        skill_desc="$(skills_read_frontmatter "$skill_file" "description" || true)"

        if [[ -z "$skill_name" ]]; then
            skill_name="$(basename "${skill_file%.*}")"
        fi

        normalized_name="$(skills_normalize_name "$skill_name")"
        printf '%s\t%s\t%s\n' "$normalized_name" "$skill_file" "$skill_desc"
    done
}

skills_resolve_alias() {
    skills_normalize_name "${1:-}"
}

skills_resolve_one() {
    local requested_name normalized_name skill_name skill_file skill_desc
    requested_name=$1
    normalized_name="$(skills_resolve_alias "$requested_name")"

    while IFS=$'\t' read -r skill_name skill_file skill_desc; do
        if [[ "$skill_name" == "$normalized_name" ]]; then
            printf '%s\t%s\t%s\n' "$skill_name" "$skill_file" "$skill_desc"
            return 0
        fi
    done < <(skills_discover)

    return 1
}

skills_resolve_many() {
    local requested_name resolved_line

    for requested_name in "$@"; do
        resolved_line="$(skills_resolve_one "$requested_name" || true)"
        if [[ -z "$resolved_line" ]]; then
            printf 'ERROR\t%s\tSkill not found\n' "$requested_name"
            return 1
        fi
        printf '%s\n' "$resolved_line"
    done
}

skills_project_root() {
    vault_resolve_project_root "${1:-"$PWD"}"
}

skills_ai_dir() {
    local project_root
    project_root="$(skills_project_root "${1:-"$PWD"}")"
    printf '%s\n' "$project_root/.ai"
}

skills_state_dir() {
    local ai_dir
    ai_dir="$(skills_ai_dir "${1:-"$PWD"}")"
    printf '%s\n' "$ai_dir/skills"
}

skills_active_file() {
    local state_dir
    state_dir="$(skills_state_dir "${1:-"$PWD"}")"
    printf '%s\n' "$state_dir/active-skills.txt"
}

skills_targets_file() {
    local state_dir
    state_dir="$(skills_state_dir "${1:-"$PWD"}")"
    printf '%s\n' "$state_dir/targets.txt"
}

skills_active_bundle_file() {
    local state_dir
    state_dir="$(skills_state_dir "${1:-"$PWD"}")"
    printf '%s\n' "$state_dir/ACTIVE_SKILLS.md"
}

skills_state_json_file() {
    local state_dir
    state_dir="$(skills_state_dir "${1:-"$PWD"}")"
    printf '%s\n' "$state_dir/active-skills.json"
}

skills_backup_dir() {
    local ai_dir
    ai_dir="$(skills_ai_dir "${1:-"$PWD"}")"
    printf '%s\n' "$ai_dir/backups/skills-standardization"
}

skills_ensure_state_dir() {
    local state_dir
    state_dir="$(skills_state_dir "${1:-"$PWD"}")"
    mkdir -p "$state_dir"
    printf '%s\n' "$state_dir"
}

skills_load_active_names() {
    local active_file
    active_file="$(skills_active_file "${1:-"$PWD"}")"

    if [[ -f "$active_file" ]]; then
        grep -v '^[[:space:]]*$' "$active_file" | grep -v '^#' || true
    fi
}

skills_load_targets() {
    local targets_file
    targets_file="$(skills_targets_file "${1:-"$PWD"}")"

    if [[ -f "$targets_file" ]]; then
        grep -v '^[[:space:]]*$' "$targets_file" | grep -v '^#' || true
    fi
}

skills_write_list_file() {
    local target_file
    target_file=$1
    shift

    mkdir -p "$(dirname "$target_file")"
    : > "$target_file"

    local item
    for item in "$@"; do
        printf '%s\n' "$item" >> "$target_file"
    done
}

skills_write_state_json() {
    local project_root json_file timestamp
    project_root="${1:-"$PWD"}"
    shift || true

    local skills=()
    local targets=()
    local mode="skills"
    local item

    for item in "$@"; do
        if [[ "$item" == "--targets" ]]; then
            mode="targets"
            continue
        fi

        if [[ "$mode" == "skills" ]]; then
            skills+=("$item")
        else
            targets+=("$item")
        fi
    done

    json_file="$(skills_state_json_file "$project_root")"
    mkdir -p "$(dirname "$json_file")"
    timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

    {
        echo "{"
        echo "  \"generated_by\": \"AI Shadow Vault\","
        echo "  \"updated_at\": \"$timestamp\","
        echo "  \"skills\": ["
        local index
        for index in "${!skills[@]}"; do
            printf '    "%s"' "${skills[$index]}"
            [[ "$index" -lt $((${#skills[@]} - 1)) ]] && printf ','
            printf '\n'
        done
        echo "  ],"
        echo "  \"targets\": ["
        for index in "${!targets[@]}"; do
            printf '    "%s"' "${targets[$index]}"
            [[ "$index" -lt $((${#targets[@]} - 1)) ]] && printf ','
            printf '\n'
        done
        echo "  ]"
        echo "}"
    } > "$json_file"
}
