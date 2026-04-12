#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
source "$SCRIPT_DIR/../lib/config.sh"
source "$SCRIPT_DIR/../lib/resolver.sh"

if [[ "$#" -ne 0 ]]; then
    ai_vault_error "Usage: ai-vault init"
    exit 1
fi

if ! ai_vault_config_exists; then
    ai_vault_error "Missing global config: $(ai_vault_config_file)"
    ai_vault_error "Run 'ai-vault install' first."
    exit 1
fi

ai_vault_load_config

PROJECT_ROOT="$(vault_resolve_project_root "$PWD")"
IDENTITY_ROOT="$(vault_resolve_identity_root "$PROJECT_ROOT")"
IDENTITY_HASH="$(vault_resolve_identity_hash "$PROJECT_ROOT")"
VAULT_DIR="$(vault_resolve_project_vault "$PROJECT_ROOT" "$AI_VAULT_CONFIG_BASE_PATH")"

PROJECT_AI_DIR="$PROJECT_ROOT/.ai"
EXTERNAL_DOCS_DIR="$VAULT_DIR/docs"
EXTERNAL_PLANS_DIR="$VAULT_DIR/plans"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

ADAPTER_NAMES=()
while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    ADAPTER_NAMES+=("$line")
done < <(printf '%s\n' "$AI_VAULT_CONFIG_ADAPTERS" | sed '/^$/d')
ALL_ADAPTERS=("AGENTS.md" "CLAUDE.md" "GEMINI.md")
PLAN_CREATE=()
PLAN_UPDATE=()
PLAN_REPAIR=()
PLAN_MIGRATE=()
PLAN_CONFLICT=()
PLAN_INFO=()
DIFF_TARGETS=()
HAS_CHANGES=0
REQUIRES_CONFIRMATION=0

HAS_GIT=0
HAS_RTK=0
HAS_COMPOSER=0
HAS_PACKAGE=0
USES_PEST=0
USES_PLAYWRIGHT=0
USES_LARAVEL=0

add_plan_item() {
    local kind="$1"
    local message="$2"

    case "$kind" in
        create) HAS_CHANGES=1; PLAN_CREATE+=("$message") ;;
        update) HAS_CHANGES=1; PLAN_UPDATE+=("$message") ;;
        repair) HAS_CHANGES=1; PLAN_REPAIR+=("$message") ;;
        migrate) HAS_CHANGES=1; PLAN_MIGRATE+=("$message") ;;
        conflict) HAS_CHANGES=1; PLAN_CONFLICT+=("$message") ;;
        info) PLAN_INFO+=("$message") ;;
    esac
}

mark_confirmation_needed() {
    REQUIRES_CONFIRMATION=1
}

require_confirmation_if_needed() {
    local answer=""

    if [[ "$HAS_CHANGES" -eq 0 || "$REQUIRES_CONFIRMATION" -eq 0 ]]; then
        return 0
    fi

    if [[ ! -t 0 ]]; then
        ai_vault_error "ai-vault init requires an interactive terminal to confirm changes."
        exit 1
    fi

    printf '\n%s Apply these changes? [y/N]: ' "$AI_VAULT_ACTION_SYMBOL"
    read -r answer
    if [[ ! "$answer" =~ ^([yY]|[yY][eE][sS])$ ]]; then
        ai_vault_error "Aborted."
        exit 1
    fi
}

adapter_enabled() {
    local target="$1"
    local item
    for item in "${ADAPTER_NAMES[@]}"; do
        [[ "$item" == "$target" ]] && return 0
    done
    return 1
}

file_has_same_content() {
    local left="$1"
    local right="$2"
    [[ -f "$left" && -f "$right" ]] || return 1
    cmp -s "$left" "$right"
}

symlink_points_to() {
    local path="$1"
    local expected="$2"
    local actual_resolved expected_resolved

    [[ -L "$path" ]] || return 1
    actual_resolved="$(vault_realpath "$path")"
    expected_resolved="$(vault_realpath "$expected")"
    [[ "$actual_resolved" == "$expected_resolved" ]]
}

timestamp_now() {
    date +"%Y%m%d-%H%M%S"
}

conflict_rename_path() {
    local target="$1"
    local dir base stem ext candidate suffix=1 stamp

    dir="$(dirname "$target")"
    base="$(basename "$target")"
    stamp="$(timestamp_now)"

    if [[ "$base" == *.* ]]; then
        stem="${base%.*}"
        ext=".${base##*.}"
    else
        stem="$base"
        ext=""
    fi

    candidate="$dir/$stem.migrated-$stamp$ext"
    while [[ -e "$candidate" ]]; do
        candidate="$dir/$stem.migrated-$stamp-$suffix$ext"
        suffix=$((suffix + 1))
    done

    printf '%s\n' "$candidate"
}

detect_repo_facts() {
    local composer_file="$PROJECT_ROOT/composer.json"
    local package_file="$PROJECT_ROOT/package.json"

    if git -C "$PROJECT_ROOT" rev-parse --show-toplevel >/dev/null 2>&1; then
        HAS_GIT=1
    fi

    if [[ "$AI_VAULT_CONFIG_RTK_INSTRUCTIONS" == "1" ]] && command -v rtk >/dev/null 2>&1; then
        HAS_RTK=1
    fi

    if [[ -f "$composer_file" ]]; then
        HAS_COMPOSER=1
        if grep -q '"pestphp/pest"' "$composer_file"; then
            USES_PEST=1
        fi
        if grep -q '"laravel/framework"' "$composer_file"; then
            USES_LARAVEL=1
        fi
    fi

    if [[ -f "$package_file" ]]; then
        HAS_PACKAGE=1
        if grep -Eq '"(@playwright/test|playwright)"' "$package_file"; then
            USES_PLAYWRIGHT=1
        fi
    fi
}

render_shared_intro() {
    cat <<EOF
# $1

Use these instructions only when they change how work should be done in this repository.
Prefer discovering facts from the codebase instead of assuming them.
EOF
}

render_shared_safety() {
    cat <<'EOF'
## Safety Rules

- Do not commit without explicit user authorization.
- Do not push without explicit user authorization.
- Do not run destructive Git commands without approval.
- Do not leave the project directory without a concrete reason.
- Do not inspect unrelated directories or repositories without reason.
- Verify tool availability before using tools.
- Prefer minimal, safe changes aligned with the existing codebase.
EOF
}

render_shared_testing() {
    echo "## Testing"
    echo
    if [[ "$USES_PEST" -eq 1 ]]; then
        echo "- Prefer Pest for PHP test execution: \`./vendor/bin/pest\`."
    fi
    if [[ "$USES_PLAYWRIGHT" -eq 1 ]]; then
        echo "- Use Playwright for browser or end-to-end validation: \`npx playwright test\`."
    fi
    if [[ "$USES_PEST" -eq 0 && "$USES_PLAYWRIGHT" -eq 0 ]]; then
        echo "- Run the narrowest relevant test command after modifying behavior."
    fi
}

render_shared_repo_notes() {
    echo "## Repo Notes"
    echo
    if [[ "$USES_LARAVEL" -eq 1 ]]; then
        echo "- This repository appears to use Laravel; follow existing application conventions instead of introducing a parallel structure."
    fi
    if [[ "$HAS_COMPOSER" -eq 1 ]]; then
        echo "- Inspect \`composer.json\` before assuming backend tooling or scripts."
    fi
    if [[ "$HAS_PACKAGE" -eq 1 ]]; then
        echo "- Inspect \`package.json\` before assuming frontend tooling or scripts."
    fi
    echo "- Prefer localized changes over broad rewrites unless the task explicitly requires them."
}

render_rtk_block() {
    if [[ "$HAS_RTK" -eq 1 ]]; then
        cat <<'EOF'
## Tooling

RTK is installed in this environment. Use RTK wrappers (`rtk ls`, `rtk read`, `rtk grep`, `rtk git`, etc. ) instead of raw commands whenever an RTK equivalent exists.
EOF
    fi
}

render_claude_file() {
    render_shared_intro "Claude Adapter"
    cat <<'EOF'

## Working Style

- Prefer direct repository inspection before asking questions.
- Keep responses concise and focused on the current task.
- When a rule is ambiguous, choose the safer and less destructive option.
EOF
    echo
    render_shared_safety
    if [[ "$HAS_RTK" -eq 1 ]]; then
        echo
        render_rtk_block
    fi
    echo
    render_shared_testing
    echo
    render_shared_repo_notes
}

render_agents_file() {
    render_shared_intro "Agent Adapter"
    cat <<'EOF'

## Workflow

- Explore first, then change only what is necessary.
- Keep edits small and easy to review.
EOF
    echo
    render_shared_safety
    if [[ "$USES_PEST" -eq 1 || "$USES_PLAYWRIGHT" -eq 1 ]]; then
        echo
        render_shared_testing
    fi
    if [[ "$HAS_RTK" -eq 1 ]]; then
        echo
        render_rtk_block
    fi
}

render_gemini_file() {
    render_shared_intro "Gemini Adapter"
    cat <<'EOF'

## Focus

- Prefer broad inspection, architecture review, and cross-file reasoning.
- Keep operational advice short and leave detailed execution rules to the repository state and task prompt.
EOF
    if [[ "$HAS_RTK" -eq 1 ]]; then
        echo
        render_rtk_block
    fi
    echo
    render_shared_safety
    if [[ "$USES_PEST" -eq 1 || "$USES_PLAYWRIGHT" -eq 1 ]]; then
        echo
        render_shared_testing
    fi
}

render_adapters() {
    local adapter
    for adapter in "${ADAPTER_NAMES[@]}"; do
        case "$adapter" in
            AGENTS.md) render_agents_file >"$TMP_DIR/$adapter" ;;
            CLAUDE.md) render_claude_file >"$TMP_DIR/$adapter" ;;
            GEMINI.md) render_gemini_file >"$TMP_DIR/$adapter" ;;
        esac
    done
}

plan_adapter_content_changes() {
    local name external_path rendered_path

    for name in "${ADAPTER_NAMES[@]}"; do
        external_path="$VAULT_DIR/$name"
        rendered_path="$TMP_DIR/$name"

        if [[ ! -e "$external_path" ]]; then
            add_plan_item create "Create external adapter: $external_path"
            continue
        fi

        if [[ -f "$external_path" ]]; then
            if ! file_has_same_content "$external_path" "$rendered_path"; then
                add_plan_item update "Update external adapter: $external_path"
                DIFF_TARGETS+=("$external_path|$rendered_path|External adapter diff for $name")
                mark_confirmation_needed
            fi
            continue
        fi

        add_plan_item repair "Replace non-file adapter target: $external_path"
        mark_confirmation_needed
    done
}

plan_project_adapter_links() {
    local name path expected

    for name in "${ADAPTER_NAMES[@]}"; do
        path="$PROJECT_ROOT/$name"
        expected="$VAULT_DIR/$name"

        if [[ ! -e "$path" && ! -L "$path" ]]; then
            add_plan_item create "Create symlink: $path -> $expected"
            continue
        fi

        if symlink_points_to "$path" "$expected"; then
            continue
        fi

        if [[ -L "$path" ]]; then
            add_plan_item repair "Repair adapter symlink: $path -> $expected"
            mark_confirmation_needed
            continue
        fi

        add_plan_item conflict "Replace existing adapter file: $path"
        DIFF_TARGETS+=("$path|$TMP_DIR/$name|Project adapter diff for $name")
        mark_confirmation_needed
    done
}

plan_disabled_adapters() {
    local name path expected

    for name in "${ALL_ADAPTERS[@]}"; do
        adapter_enabled "$name" && continue
        path="$PROJECT_ROOT/$name"
        expected="$VAULT_DIR/$name"

        if symlink_points_to "$path" "$expected"; then
            add_plan_item repair "Remove disabled adapter symlink: $path"
            mark_confirmation_needed
        fi
    done
}

plan_ai_root() {
    if [[ ! -e "$PROJECT_AI_DIR" && ! -L "$PROJECT_AI_DIR" ]]; then
        add_plan_item create "Create directory: $PROJECT_AI_DIR"
        return
    fi

    if [[ -d "$PROJECT_AI_DIR" && ! -L "$PROJECT_AI_DIR" ]]; then
        return
    fi

    add_plan_item conflict "Replace non-directory .ai path: $PROJECT_AI_DIR"
    mark_confirmation_needed
}

plan_ai_links() {
    local name project_path external_path

    for name in docs plans; do
        project_path="$PROJECT_AI_DIR/$name"
        external_path="$VAULT_DIR/$name"

        if [[ ! -e "$project_path" && ! -L "$project_path" ]]; then
            add_plan_item create "Create symlink: $project_path -> $external_path"
            continue
        fi

        if symlink_points_to "$project_path" "$external_path"; then
            continue
        fi

        if [[ -L "$project_path" ]]; then
            add_plan_item repair "Repair .ai symlink: $project_path -> $external_path"
            mark_confirmation_needed
            continue
        fi

        if [[ -d "$project_path" ]]; then
            add_plan_item migrate "Migrate directory into external vault: $project_path -> $external_path"
            mark_confirmation_needed
            continue
        fi

        add_plan_item conflict "Replace non-directory .ai path: $project_path"
        mark_confirmation_needed
    done
}

build_git_exclude_candidate() {
    local source_file="$1"
    local destination_file="$2"
    local stripped_file="$TMP_DIR/exclude.stripped"
    local adapter

    [[ -f "$source_file" ]] || : >"$source_file"

    awk '
        BEGIN { skip = 0 }
        /^# >>> ai-shadow-vault >>>$/ { skip = 1; next }
        skip == 1 && /^# <<< ai-shadow-vault <<<$/
        {
            skip = 0
            next
        }
        skip == 0 { print }
    ' "$source_file" >"$stripped_file"

    {
        cat "$stripped_file"
        [[ -s "$stripped_file" ]] && printf '\n'
        echo "# >>> ai-shadow-vault >>>"
        echo "/.ai/"
        for adapter in "${ADAPTER_NAMES[@]}"; do
            echo "/$adapter"
        done
        echo "# <<< ai-shadow-vault <<<"
    } >"$destination_file"
}

plan_git_exclude() {
    local git_dir exclude_path candidate_path

    if ! git_dir="$(git -C "$PROJECT_ROOT" rev-parse --path-format=absolute --git-dir 2>/dev/null)"; then
        add_plan_item info "No Git repository detected; skipping .git/info/exclude update."
        return
    fi

    exclude_path="$git_dir/info/exclude"
    candidate_path="$TMP_DIR/exclude.plan"

    if [[ ! -f "$exclude_path" ]]; then
        add_plan_item create "Create local Git exclude file: $exclude_path"
        return
    fi

    build_git_exclude_candidate "$exclude_path" "$candidate_path"
    if ! cmp -s "$exclude_path" "$candidate_path"; then
        add_plan_item update "Update managed block in: $exclude_path"
    fi
}

show_summary_section() {
    local symbol="$1"
    local title="$2"
    shift
    shift
    local items=("$@")
    local item

    [[ "${#items[@]}" -gt 0 ]] || return 0
    printf '\n%s %s\n' "$symbol" "$title"
    for item in "${items[@]}"; do
        printf '  - %s\n' "$item"
    done
}

show_diffs() {
    local spec left right label

    [[ "${#DIFF_TARGETS[@]}" -gt 0 ]] || return 0

    printf '\nDiffs:\n'
    for spec in "${DIFF_TARGETS[@]}"; do
        IFS='|' read -r left right label <<<"$spec"
        printf '\n%s\n' "$label"
        diff -u "$left" "$right" || true
    done
}

print_summary() {
    printf 'AI Shadow Vault\n'
    printf 'Project root: %s\n' "$PROJECT_ROOT"
    printf 'Identity root: %s\n' "$IDENTITY_ROOT"
    printf 'Vault path: %s\n' "$VAULT_DIR"
    printf 'Configured adapters: %s\n' "${ADAPTER_NAMES[*]}"

    if [[ "$HAS_CHANGES" -eq 0 ]]; then
        printf '\n%s No changes required.\n' "$AI_VAULT_SUCCESS_SYMBOL"
        return
    fi

    if [[ "${#PLAN_CREATE[@]}" -gt 0 ]]; then
        show_summary_section "$AI_VAULT_ACTION_SYMBOL" "Create" "${PLAN_CREATE[@]}"
    fi
    if [[ "${#PLAN_UPDATE[@]}" -gt 0 ]]; then
        show_summary_section "$AI_VAULT_ACTION_SYMBOL" "Update" "${PLAN_UPDATE[@]}"
    fi
    if [[ "${#PLAN_REPAIR[@]}" -gt 0 ]]; then
        show_summary_section "$AI_VAULT_WARNING_SYMBOL" "Repair" "${PLAN_REPAIR[@]}"
    fi
    if [[ "${#PLAN_MIGRATE[@]}" -gt 0 ]]; then
        show_summary_section "$AI_VAULT_WARNING_SYMBOL" "Migrate" "${PLAN_MIGRATE[@]}"
    fi
    if [[ "${#PLAN_CONFLICT[@]}" -gt 0 ]]; then
        show_summary_section "$AI_VAULT_ERROR_SYMBOL" "Conflicts" "${PLAN_CONFLICT[@]}"
    fi
    if [[ "${#PLAN_INFO[@]}" -gt 0 ]]; then
        show_summary_section "$AI_VAULT_WARNING_SYMBOL" "Info" "${PLAN_INFO[@]}"
    fi
    show_diffs
}

ensure_directory_path() {
    local path="$1"

    if [[ -d "$path" && ! -L "$path" ]]; then
        return
    fi

    if [[ -e "$path" || -L "$path" ]]; then
        rm -rf "$path"
    fi
    mkdir -p "$path"
}

write_adapter_if_needed() {
    local target="$1"
    local source="$2"

    mkdir -p "$(dirname "$target")"
    if [[ -f "$target" ]] && file_has_same_content "$target" "$source"; then
        return
    fi

    if [[ -e "$target" && ! -f "$target" ]]; then
        rm -rf "$target"
    fi
    cp "$source" "$target"
}

ensure_symlink_path() {
    local target="$1"
    local source="$2"

    mkdir -p "$(dirname "$target")"
    if symlink_points_to "$target" "$source"; then
        return
    fi

    if [[ -e "$target" || -L "$target" ]]; then
        rm -rf "$target"
    fi
    ln -s "$source" "$target"
}

migrate_directory_contents() {
    local source_dir="$1"
    local target_dir="$2"
    local path rel destination

    mkdir -p "$target_dir"

    while IFS= read -r -d '' path; do
        rel="${path#$source_dir/}"
        mkdir -p "$target_dir/$rel"
    done < <(find "$source_dir" -mindepth 1 -type d -print0)

    while IFS= read -r -d '' path; do
        rel="${path#$source_dir/}"
        destination="$target_dir/$rel"
        mkdir -p "$(dirname "$destination")"
        if [[ -e "$destination" ]]; then
            destination="$(conflict_rename_path "$destination")"
        fi
        mv "$path" "$destination"
    done < <(find "$source_dir" -type f -print0)

    rm -rf "$source_dir"
}

update_git_exclude() {
    local git_dir exclude_file candidate_file

    git_dir="$(git -C "$PROJECT_ROOT" rev-parse --path-format=absolute --git-dir 2>/dev/null)" || return 0
    exclude_file="$git_dir/info/exclude"
    candidate_file="$TMP_DIR/exclude.apply"

    mkdir -p "$(dirname "$exclude_file")"
    [[ -f "$exclude_file" ]] || touch "$exclude_file"

    build_git_exclude_candidate "$exclude_file" "$candidate_file"
    if ! cmp -s "$exclude_file" "$candidate_file"; then
        cp "$candidate_file" "$exclude_file"
    fi
}

apply_changes() {
    local name project_path external_path

    mkdir -p "$VAULT_DIR"
    mkdir -p "$EXTERNAL_DOCS_DIR" "$EXTERNAL_PLANS_DIR"

    ensure_directory_path "$PROJECT_AI_DIR"

    for name in docs plans; do
        project_path="$PROJECT_AI_DIR/$name"
        external_path="$VAULT_DIR/$name"

        mkdir -p "$external_path"
        if [[ -d "$project_path" && ! -L "$project_path" ]]; then
            migrate_directory_contents "$project_path" "$external_path"
        fi
        ensure_symlink_path "$project_path" "$external_path"
    done

    for name in "${ADAPTER_NAMES[@]}"; do
        external_path="$VAULT_DIR/$name"
        write_adapter_if_needed "$external_path" "$TMP_DIR/$name"
        ensure_symlink_path "$PROJECT_ROOT/$name" "$external_path"
    done

    for name in "${ALL_ADAPTERS[@]}"; do
        adapter_enabled "$name" && continue
        project_path="$PROJECT_ROOT/$name"
        external_path="$VAULT_DIR/$name"
        if symlink_points_to "$project_path" "$external_path"; then
            rm -f "$project_path"
        fi
    done

    update_git_exclude
}

detect_repo_facts
plan_ai_root
plan_ai_links
plan_project_adapter_links
plan_disabled_adapters
plan_git_exclude
render_adapters
plan_adapter_content_changes
print_summary
require_confirmation_if_needed

if [[ "$HAS_CHANGES" -eq 0 ]]; then
    exit 0
fi

apply_changes

printf '%s Initialization complete.\n' "$AI_VAULT_SUCCESS_SYMBOL"
