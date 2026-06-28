#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
source "$SCRIPT_DIR/../lib/config.sh"
source "$SCRIPT_DIR/../lib/plugin-detect.sh"
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

CONFIG_FILE_PATH="$(ai_vault_config_file)"
MISSING_CONFIG_FIELDS=()
for _field in superpowers_instructions context_mode_instructions use_superpowers_docs adhd_instructions; do
    if ! grep -qE "\"$_field\"[[:space:]]*:" "$CONFIG_FILE_PATH"; then
        MISSING_CONFIG_FIELDS+=("$_field")
    fi
done
if (( ${#MISSING_CONFIG_FIELDS[@]} > 0 )); then
    ai_vault_warning "Config schema outdated. Missing fields: $(IFS=', '; printf '%s' "${MISSING_CONFIG_FIELDS[*]}")"
    ai_vault_warning "Run 'ai-vault install' to enable new plugin toggles."
fi
unset _field

PROJECT_ROOT="$(vault_resolve_project_root "$PWD")"
IDENTITY_ROOT="$(vault_resolve_identity_root "$PROJECT_ROOT")"
IDENTITY_HASH="$(vault_resolve_identity_hash "$PROJECT_ROOT")"
VAULT_DIR="$(vault_resolve_project_vault "$PROJECT_ROOT" "$AI_VAULT_CONFIG_BASE_PATH")"

PROJECT_AI_DIR="$PROJECT_ROOT/.ai"
EXTERNAL_DOCS_DIR="$VAULT_DIR/docs"
EXTERNAL_PLANS_DIR="$VAULT_DIR/plans"
SUPERPOWERS_DOCS_ROOT="$PROJECT_ROOT/docs/superpowers"
SUPERPOWERS_SPECS_DIR="$SUPERPOWERS_DOCS_ROOT/specs"
SUPERPOWERS_PLANS_DIR="$SUPERPOWERS_DOCS_ROOT/plans"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
TMP_DOCS_DIR="$TMP_DIR/docs"

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
HAS_SUPERPOWERS_CLAUDE=0
HAS_SUPERPOWERS_AGENTS=0
HAS_SUPERPOWERS_GEMINI=0
HAS_CONTEXT_MODE_CLAUDE=0
HAS_CONTEXT_MODE_AGENTS=0
HAS_CONTEXT_MODE_GEMINI=0
HAS_ADHD_CLAUDE=0
HAS_ADHD_AGENTS=0
HAS_ADHD_GEMINI=0
HAS_SUPERPOWERS_ANY=0
USE_SUPERPOWERS_DOCS=0
DID_REVERSE_MIGRATION=0
PERSIST_USE_SUPERPOWERS_DOCS=0
HAS_COMPOSER=0
HAS_PACKAGE=0
USES_PEST=0
USES_PLAYWRIGHT=0
USES_LARAVEL=0
STACK_PHP=""
STACK_BACKEND_FRAMEWORK=""
STACK_LARAVEL_NOVA=""
STACK_FILAMENT=""
STACK_VUE=""
STACK_QUASAR=""
STACK_PRIMEVUE=""
STACK_PEST=""
STACK_PLAYWRIGHT=""

MANAGED_DOC_FILES=(
    "index.md"
    "core/autoload-policy.md"
    "core/quick-start.md"
    "core/common-mistakes.md"
    "core/architecture-map.md"
    "learnings/generic/testing-strategy.md"
    "learnings/generic/domain-glossary.md"
    "learnings/laravel/filament-actions.md"
    "learnings/laravel/policies-permissions.md"
    "learnings/node/frontend-delivery.md"
)

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
    local parser_file="$TMP_DIR/repo-facts.env"
    local python_bin=""

    if git -C "$PROJECT_ROOT" rev-parse --show-toplevel >/dev/null 2>&1; then
        HAS_GIT=1
    fi

    if command -v rtk >/dev/null 2>&1; then
        HAS_RTK=1
    fi

    if [[ -f "$composer_file" ]]; then
        HAS_COMPOSER=1
    fi

    if [[ -f "$package_file" ]]; then
        HAS_PACKAGE=1
    fi

    python_bin="$(command -v python3 || true)"
    if [[ -z "$python_bin" ]]; then
        return
    fi

    if ! COMPOSER_FILE="$composer_file" PACKAGE_FILE="$package_file" "$python_bin" >"$parser_file" <<'PY'
import json
import os
import shlex
from pathlib import Path

OUTPUT_KEYS = (
    "STACK_PHP",
    "STACK_BACKEND_FRAMEWORK",
    "STACK_LARAVEL_NOVA",
    "STACK_FILAMENT",
    "STACK_VUE",
    "STACK_QUASAR",
    "STACK_PRIMEVUE",
    "STACK_PEST",
    "STACK_PLAYWRIGHT",
    "USES_PEST",
    "USES_PLAYWRIGHT",
    "USES_LARAVEL",
)


def load_json(path_value):
    if not path_value:
        return {}

    path = Path(path_value)
    if not path.is_file():
        return {}

    try:
        with path.open("r", encoding="utf-8") as handle:
            data = json.load(handle)
    except (OSError, json.JSONDecodeError):
        return {}

    return data if isinstance(data, dict) else {}


def merged_dependencies(data):
    merged = {}
    for key in ("require", "require-dev", "dependencies", "devDependencies"):
        section = data.get(key)
        if isinstance(section, dict):
            for package_name, version in section.items():
                if isinstance(package_name, str) and isinstance(version, str):
                    merged[package_name] = version
    return merged


def dependency_version(deps, *package_names):
    for package_name in package_names:
        version = deps.get(package_name)
        if isinstance(version, str) and version.strip():
            return version.strip()
    return ""


def format_signal(label, value):
    value = value.strip()
    return f"{label} {value}".strip() if value else label


composer = load_json(os.environ.get("COMPOSER_FILE", ""))
package = load_json(os.environ.get("PACKAGE_FILE", ""))
composer_deps = merged_dependencies(composer)
package_deps = merged_dependencies(package)

values = {key: "" for key in OUTPUT_KEYS}

php_version = dependency_version(composer_deps, "php")
if php_version:
    values["STACK_PHP"] = format_signal("PHP", php_version)

if "laravel/framework" in composer_deps:
    values["STACK_BACKEND_FRAMEWORK"] = format_signal("Laravel", composer_deps["laravel/framework"])
    values["USES_LARAVEL"] = "1"

nova_version = dependency_version(composer_deps, "laravel/nova")
if nova_version:
    values["STACK_LARAVEL_NOVA"] = format_signal("Laravel Nova", nova_version)

filament_version = dependency_version(composer_deps, "filament/filament")
if filament_version:
    values["STACK_FILAMENT"] = format_signal("Filament", filament_version)
elif any(package_name.startswith("filament/") for package_name in composer_deps):
    values["STACK_FILAMENT"] = "Filament"

pest_version = dependency_version(composer_deps, "pestphp/pest")
if pest_version:
    values["STACK_PEST"] = format_signal("Pest", pest_version)
    values["USES_PEST"] = "1"

vue_version = dependency_version(package_deps, "vue")
if vue_version:
    values["STACK_VUE"] = format_signal("Vue", vue_version)

quasar_version = dependency_version(package_deps, "quasar")
if quasar_version:
    values["STACK_QUASAR"] = format_signal("Quasar", quasar_version)
elif any(package_name.startswith("@quasar/") for package_name in package_deps):
    values["STACK_QUASAR"] = "Quasar"

primevue_version = dependency_version(package_deps, "primevue")
if primevue_version:
    values["STACK_PRIMEVUE"] = format_signal("PrimeVue", primevue_version)

playwright_version = dependency_version(package_deps, "@playwright/test", "playwright")
if playwright_version:
    values["STACK_PLAYWRIGHT"] = format_signal("Playwright", playwright_version)
    values["USES_PLAYWRIGHT"] = "1"

for key in OUTPUT_KEYS:
    print(f"{key}={shlex.quote(values[key])}")
PY
    then
        return
    fi

    # shellcheck disable=SC1090
    source "$parser_file"
    USES_PEST="${USES_PEST:-0}"
    USES_PLAYWRIGHT="${USES_PLAYWRIGHT:-0}"
    USES_LARAVEL="${USES_LARAVEL:-0}"
}

stack_snapshot_has_content() {
    [[ -n "$STACK_PHP" || -n "$STACK_BACKEND_FRAMEWORK" || -n "$STACK_LARAVEL_NOVA" || -n "$STACK_FILAMENT" || -n "$STACK_VUE" || -n "$STACK_QUASAR" || -n "$STACK_PRIMEVUE" || -n "$STACK_PEST" || -n "$STACK_PLAYWRIGHT" ]]
}

render_stack_snapshot_group() {
    local title="$1"
    shift
    local items=("$@")
    local item
    local has_items=0

    for item in "${items[@]}"; do
        if [[ -n "$item" ]]; then
            has_items=1
            break
        fi
    done

    [[ "$has_items" -eq 1 ]] || return 0

    echo "### $title"
    echo
    for item in "${items[@]}"; do
        [[ -n "$item" ]] || continue
        echo "- $item"
    done
    echo
}

render_shared_stack_snapshot() {
    stack_snapshot_has_content || return 0

    echo "## Stack"
    echo
    echo "<!-- Authoritative versions live in composer.json / package.json. This block is orientation only; fill it in and keep it short. -->"
    echo
    render_stack_snapshot_group "Backend" \
        "$STACK_PHP" \
        "$STACK_BACKEND_FRAMEWORK" \
        "$STACK_LARAVEL_NOVA" \
        "$STACK_FILAMENT"
    render_stack_snapshot_group "Frontend / UI" \
        "$STACK_VUE" \
        "$STACK_QUASAR" \
        "$STACK_PRIMEVUE"
    render_stack_snapshot_group "Testing" \
        "$STACK_PEST" \
        "$STACK_PLAYWRIGHT"
}


prompt_superpowers_docs() {
    local stored_value="${AI_VAULT_CONFIG_USE_SUPERPOWERS_DOCS:-}"
    local answer=""
    local next_value=0

    if [[ "$HAS_SUPERPOWERS_ANY" -ne 1 ]]; then
        USE_SUPERPOWERS_DOCS=0
        return
    fi
    if [[ "$stored_value" == "1" ]]; then
        USE_SUPERPOWERS_DOCS=1
        return
    fi
    if [[ ! -t 0 ]]; then
        USE_SUPERPOWERS_DOCS=0
        return
    fi
    printf '%s Superpowers detected. Use docs/superpowers/ for specs and plans instead of .ai/docs and .ai/plans? [Y/n]: ' "$AI_VAULT_ACTION_SYMBOL"
    read -r answer
    answer="${answer//$'\r'/}"
    if [[ -z "$answer" || "$answer" =~ ^([yY]|[yY][eE][sS])$ ]]; then
        USE_SUPERPOWERS_DOCS=1
    else
        USE_SUPERPOWERS_DOCS=0
    fi

    if [[ "$USE_SUPERPOWERS_DOCS" != "$stored_value" ]]; then
        PERSIST_USE_SUPERPOWERS_DOCS=1
    fi
}


render_claude_file() {
    echo "@AGENTS.md"
    echo
    echo "## Claude Code only"
    echo
    if [[ "$HAS_SUPERPOWERS_CLAUDE" -eq 1 && "$AI_VAULT_CONFIG_SUPERPOWERS_INSTRUCTIONS" == "1" ]]; then
        echo "- @use superpowers. Activate the subagents and skills needed for the task. If a specific skill must run, invoke it explicitly rather than relying on auto-selection (weaker models pick skills unreliably)."
    fi
    if [[ "$HAS_ADHD_CLAUDE" -eq 1 && "$AI_VAULT_CONFIG_ADHD_INSTRUCTIONS" == "1" ]]; then
        echo "- @use i-have-adhd. Shape every reply ADHD-friendly: lead with the next concrete action, number multi-step work, restate task state each turn, cap lists at five, no preamble or closers. Structure only — does not override the pt-PT output rule. Invoke the skill explicitly rather than relying on auto-selection."
    fi
    echo "- The Git workflow in AGENTS.md is enforced deterministically where possible in ~/.claude/settings.json through permissions and a PreToolUse guard. The guard is authoritative for protected-branch pushes and commit-message checks; AGENTS.md remains authoritative for workflow decisions that require repository context."
}

render_agents_file() {
    echo "# Project agent instructions"
    echo
    echo "## Output & language"
    echo
    echo "- Reply to the user in European Portuguese (pt-PT), always — regardless of the language of these instructions or of the codebase."
    echo "- Code, identifiers, comments, commit messages: English."
    if [[ "$USES_LARAVEL" -eq 1 ]]; then
        echo "- User-facing strings go through the project's lang files — never hardcoded, in any language."
    fi
    if stack_snapshot_has_content; then
        echo
        render_shared_stack_snapshot
    fi
    echo
    cat <<'EOF'
## Working rules

- Read a file before changing it. Never list or cite a file you have not opened; if a path is deduced but unconfirmed, mark it `[?]`.
- If you don't know or can't verify, say so and stop — never guess.
- When claiming something about existing code, cite `path:line`.
- Verify exact versions from composer.json / package.json before relying on version-specific APIs.
- Do not invent APIs, signatures, config keys, or undocumented behavior.
- Implement exactly the requested scope: complete and correct, with no extra features, abstractions, config keys, or files.
- Be concise in conversational output (no preamble, postamble, or summaries unless asked). Never shorten code, plans, or required translations.
EOF
    if [[ "$USES_LARAVEL" -eq 1 ]]; then
        echo
        cat <<'EOF'
## Laravel conventions

- Tables: plural English (`users`, `project_types`).
- Pivot tables: alphabetical singular (`project_user`).
- Models: singular PascalCase (`ProjectType`).
- Foreign keys: `model_id` (e.g. `project_id`). No Portuguese in code.
- Every new `__('...')` / `@lang('...')` string must be added to the project's lang resources (verify lang/ vs resources/lang at implementation time).
EOF
    fi
    if [[ "$HAS_RTK" -eq 1 ]]; then
        echo
        cat <<'EOF'
## Tooling

- Prefer RTK wrappers (`rtk ls`, `rtk read`, `rtk grep`, `rtk git`, …) over raw commands whenever an RTK equivalent exists.
- If external library/API details are needed and Context7 is available, use it before making assumptions.
EOF
    fi
    echo
    cat <<'EOF'
## Git

### Branches and worktrees

- Protected branches are `main`, `develop`, `stage`, `release/*`, and `hotfix/*`. Never push directly to them.
- When starting on `main`, `develop`, or `stage`, create a sibling worktree from the current `HEAD` and work on a new branch named `<username>/task-<number>-<slug>`.
- Create the branch and worktree atomically with `rtk git worktree add -b "<username>/task-<number>-<slug>" "../<repo>-task-<number>-<slug>" HEAD`.
- Derive `<username>` from `git config gitlab.pdmfc.com.username`, lowercase it, transliterate it to ASCII, and remove every character outside `[a-z0-9]`. If the result is empty or `gitlab.pdmfc.com.username` is missing, stop, report the problem, and ask the user to configure it in `~/.gitconfig` for global scope or `<repo>/.git/config` for repository scope. Never edit either file automatically.
- Use the task number from the plan. If none is provided, use `000`. Derive `<slug>` from the plan title as lowercase ASCII kebab-case.
- On any other branch, including `release/*` and `hotfix/*`, keep the current branch. Because `release/*` and `hotfix/*` are protected, stop before publication and ask the user for a non-protected branch.
- If `HEAD` is detached, a protected branch has uncommitted changes, or the target branch/worktree already exists or conflicts, stop, preserve all changes, report the current branch, `git status`, and the exact conflict, and ask the user to resolve it manually. Never stash, reset, overwrite, clean, or remove a worktree automatically.
- Worktree cleanup is the user's responsibility.

### Commit and delivery workflow

- A user declaring the task finished, or applicable checks becoming green, only moves the task into review. It never authorizes an immediate commit.
- Review the uncommitted working tree first. Commit only after the review is green and, when `pestphp/pest` is installed, Pest is green.
- Stage only files belonging to the task. Never use a broad add when unrelated changes exist.
- Use Conventional Commits with a non-empty, single-line subject, no trailing period, subject and body lines no longer than 72 characters, optional multiline body, and one of: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`. Subject capitalization is not enforced, matching is case-insensitive, and merge commits are exempt.
- The commit must contain `#<task-number>`; use `#000` when the plan has no task number. Prefer `<type>(<optional-scope>): <subject> #<number>`.
- Never include `Co-authored-by`, `Generated-by`, or any statement that AI, a bot, or an agent created the commit.
- Before pushing, inspect the actual commit message and trailers. Do not push an invalid commit.
- Push only a non-protected task branch with `rtk git push -u <remote> HEAD`; do not use implicit, wildcard, mirror, force, or explicit destination refspec pushes. Then create a GitHub Pull Request with `gh pr create` or a GitLab Merge Request with `glab mr create`, according to the remote provider. Target the plan's `Base branch`, defaulting to `develop` when absent. Never merge automatically.
- If the provider CLI or authentication is unavailable, report the delivery blocker without bypassing branch protection.
EOF
}


render_adapters() {
    local adapter
    for adapter in "${ADAPTER_NAMES[@]}"; do
        case "$adapter" in
            AGENTS.md) render_agents_file >"$TMP_DIR/$adapter" ;;
            CLAUDE.md) render_claude_file >"$TMP_DIR/$adapter" ;;
            GEMINI.md) ln -sf "$TMP_DIR/AGENTS.md" "$TMP_DIR/GEMINI.md" ;;
        esac
    done
}

render_docs_index() {
    cat <<'EOF'
# AI Docs Index

## Core (autoload)
- `core/autoload-policy.md`
- `core/quick-start.md`
- `core/common-mistakes.md`
- `core/architecture-map.md`

## Learnings (on-demand)
- `learnings/generic/*`: cross-stack guidance
- `learnings/laravel/*`: Laravel and Filament specifics
- `learnings/node/*`: Node/frontend specifics

Read only what is needed for the current task.
EOF
}

render_core_autoload_policy() {
    cat <<'EOF'
# Autoload Policy

## Load Order
1. `AGENTS.md`
2. `.ai/docs/core/autoload-policy.md`
3. `.ai/docs/core/quick-start.md`
4. `.ai/docs/core/common-mistakes.md`
5. `.ai/docs/core/architecture-map.md`
6. `.ai/docs/index.md`

## Core Autoload
- The load order above is the full default auto-load set.
- Do not auto-load learning files by default.

## Conditional Load
- Select learning files by task scope and detected stack.
- Load one learning file at a time.
- Re-check task scope before loading additional files.

## Never Auto-Load
- `.ai/plans/sessions/**`
- `.ai/plans/completions/**`
- `.ai/plans/archive/**`
- `.ai/docs/archive/**`
- Temporary notes, debug dumps, and generated transcripts.

## Decision Examples
- Need Filament bulk action rule: load `.ai/docs/learnings/laravel/filament-actions.md`.
- Need generic test strategy: load `.ai/docs/learnings/generic/testing-strategy.md`.
- Need frontend build context: load `.ai/docs/learnings/node/frontend-delivery.md` only when `package.json` is relevant.
EOF
}

render_core_quick_start() {
    cat <<'EOF'
# Quick Start

1. Confirm task goal and acceptance criteria.
2. Inspect repository facts before assumptions.
3. Apply minimal changes aligned with existing conventions.
4. Run narrow tests relevant to changed behavior.
5. Report outcomes and remaining risks clearly.
EOF
}

render_core_common_mistakes() {
    cat <<'EOF'
# Common Mistakes

- Loading all learnings at once instead of task-scoped files.
- Treating provider adapters as canonical policy instead of `AGENTS.md`.
- Assuming stack features without checking `composer.json` / `package.json`.
- Mixing historical notes into active context.
- Running broad rewrites where localized edits are enough.
EOF
}

render_core_architecture_map() {
    cat <<'EOF'
# Architecture Map

- `AGENTS.md`: canonical runtime contract for all agents.
- `CLAUDE.md` and `GEMINI.md`: thin provider adapters.
- `.ai/docs/core/*`: always-loaded baseline.
- `.ai/docs/learnings/*`: thematic, stack-aware, on-demand.
- `.ai/plans/sessions|completions|archive`: historical records, never auto-loaded.
EOF
}

render_learning_generic_testing() {
    cat <<'EOF'
# Testing Strategy (Generic)

## Objective
Choose the narrowest test scope that validates the changed behavior.

## Include
- Unit/service tests for isolated logic.
- Feature/integration tests for user-facing behavior.
- Targeted regression checks for bug fixes.

## Exclude
- Full-suite runs when a narrow suite is sufficient.
- Tool-specific commands that are not present in project manifests.
EOF
}

render_learning_generic_domain_glossary() {
    cat <<'EOF'
# Domain Glossary (Generic)

Use this file for stable business vocabulary shared across stacks.

Keep entries concise:
- Term
- Meaning
- Source of truth (module, model, or policy)
EOF
}

render_learning_laravel_filament() {
    cat <<'EOF'
# Filament Resources and Actions

Read when tasks involve Resources, Pages, Actions, Bulk Actions, or Widgets.

Focus:
- Authorization checks in actions and bulk actions.
- Query efficiency for tables and filters.
- Avoiding duplicate business rules between UI actions and backend services.
EOF
}

render_learning_laravel_policies() {
    cat <<'EOF'
# Laravel Policies and Permissions

Read when tasks touch authorization flows.

Focus:
- Central policy ownership.
- Consistent checks across controllers, jobs, and admin actions.
- Preventing bypass via direct service calls.
EOF
}

render_learning_node_frontend() {
    cat <<'EOF'
# Frontend Delivery (Node)

Read when tasks involve frontend build, tooling, or runtime packages.

Focus:
- Validate scripts and versions from `package.json` before assumptions.
- Keep build/test changes aligned with existing tooling.
- Avoid introducing parallel frontend pipelines.
EOF
}

render_managed_docs() {
    mkdir -p "$TMP_DOCS_DIR/core" "$TMP_DOCS_DIR/learnings/generic" "$TMP_DOCS_DIR/learnings/laravel" "$TMP_DOCS_DIR/learnings/node"
    render_docs_index >"$TMP_DOCS_DIR/index.md"
    render_core_autoload_policy >"$TMP_DOCS_DIR/core/autoload-policy.md"
    render_core_quick_start >"$TMP_DOCS_DIR/core/quick-start.md"
    render_core_common_mistakes >"$TMP_DOCS_DIR/core/common-mistakes.md"
    render_core_architecture_map >"$TMP_DOCS_DIR/core/architecture-map.md"
    render_learning_generic_testing >"$TMP_DOCS_DIR/learnings/generic/testing-strategy.md"
    render_learning_generic_domain_glossary >"$TMP_DOCS_DIR/learnings/generic/domain-glossary.md"
    render_learning_laravel_filament >"$TMP_DOCS_DIR/learnings/laravel/filament-actions.md"
    render_learning_laravel_policies >"$TMP_DOCS_DIR/learnings/laravel/policies-permissions.md"
    render_learning_node_frontend >"$TMP_DOCS_DIR/learnings/node/frontend-delivery.md"
}

plan_adapter_content_changes() {
    local name external_path rendered_path agents_external_path

    for name in "${ADAPTER_NAMES[@]}"; do
        external_path="$VAULT_DIR/$name"
        rendered_path="$TMP_DIR/$name"

        if [[ "$name" == "GEMINI.md" ]]; then
            agents_external_path="$VAULT_DIR/AGENTS.md"
            if [[ ! -e "$external_path" && ! -L "$external_path" ]]; then
                add_plan_item create "Create external adapter symlink: $external_path -> $agents_external_path"
            elif ! symlink_points_to "$external_path" "$agents_external_path"; then
                add_plan_item repair "Repair GEMINI.md symlink: $external_path -> $agents_external_path"
                mark_confirmation_needed
            fi
            continue
        fi

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
        if [[ "$USE_SUPERPOWERS_DOCS" -eq 1 ]]; then
            if [[ "$name" == "docs" ]]; then
                external_path="$SUPERPOWERS_SPECS_DIR"
            else
                external_path="$SUPERPOWERS_PLANS_DIR"
            fi
        fi

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

plan_ai_dynamic_subdirs() {
    local ai_dir_path dir_name dynamic_target

    if [[ "$USE_SUPERPOWERS_DOCS" -eq 1 ]]; then
        while IFS= read -r -d '' ai_dir_path; do
            dir_name="$(basename "$ai_dir_path")"
            [[ "$dir_name" == "docs" || "$dir_name" == "plans" ]] && continue
            dynamic_target="$SUPERPOWERS_DOCS_ROOT/$dir_name"
            if [[ -d "$ai_dir_path" && ! -L "$ai_dir_path" ]]; then
                add_plan_item migrate "Migrate dynamic .ai directory: $ai_dir_path -> $dynamic_target"
                mark_confirmation_needed
                continue
            fi
            if [[ -L "$PROJECT_AI_DIR/$dir_name" ]] && ! symlink_points_to "$PROJECT_AI_DIR/$dir_name" "$dynamic_target"; then
                add_plan_item repair "Repair dynamic .ai symlink: $PROJECT_AI_DIR/$dir_name -> $dynamic_target"
                mark_confirmation_needed
            fi
        done < <(find "$PROJECT_AI_DIR" -mindepth 1 -maxdepth 1 \( -type d -o -type l \) -print0 2>/dev/null || true)
    else
        while IFS= read -r -d '' ai_dir_path; do
            dir_name="$(basename "$ai_dir_path")"
            [[ "$dir_name" == "specs" || "$dir_name" == "plans" ]] && continue
            if [[ -L "$PROJECT_AI_DIR/$dir_name" ]] && symlink_points_to "$PROJECT_AI_DIR/$dir_name" "$SUPERPOWERS_DOCS_ROOT/$dir_name"; then
                add_plan_item migrate "Revert dynamic .ai symlink target: $PROJECT_AI_DIR/$dir_name -> $VAULT_DIR/$dir_name"
                mark_confirmation_needed
            fi
        done < <(find "$SUPERPOWERS_DOCS_ROOT" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null || true)
    fi
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
        if [[ "$USE_SUPERPOWERS_DOCS" -eq 1 ]]; then
            echo "/docs/superpowers/"
        fi
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

plan_managed_docs() {
    local relative_path source_path target_path
    for relative_path in "${MANAGED_DOC_FILES[@]}"; do
        source_path="$TMP_DOCS_DIR/$relative_path"
        target_path="$EXTERNAL_DOCS_DIR/$relative_path"

        if [[ ! -e "$target_path" ]]; then
            add_plan_item create "Create managed doc: $target_path"
            continue
        fi

        if [[ -f "$target_path" ]]; then
            continue
        fi

        add_plan_item repair "Replace non-file managed doc path: $target_path"
        mark_confirmation_needed
    done
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

write_file_if_missing() {
    local target="$1"
    local source="$2"

    mkdir -p "$(dirname "$target")"
    if [[ -e "$target" ]]; then
        return
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
    local name project_path external_path standard_external_path superpowers_target dir_name ai_dir_path dynamic_target old_target adapters_csv

    mkdir -p "$VAULT_DIR"
    mkdir -p "$EXTERNAL_DOCS_DIR" "$EXTERNAL_PLANS_DIR"
    if [[ "$USE_SUPERPOWERS_DOCS" -eq 1 ]]; then
        mkdir -p "$SUPERPOWERS_SPECS_DIR" "$SUPERPOWERS_PLANS_DIR"
    fi

    ensure_directory_path "$PROJECT_AI_DIR"

    for name in docs plans; do
        project_path="$PROJECT_AI_DIR/$name"
        standard_external_path="$VAULT_DIR/$name"
        external_path="$standard_external_path"
        if [[ "$name" == "docs" ]]; then
            superpowers_target="$SUPERPOWERS_SPECS_DIR"
        else
            superpowers_target="$SUPERPOWERS_PLANS_DIR"
        fi
        if [[ "$USE_SUPERPOWERS_DOCS" -eq 1 ]]; then
            external_path="$superpowers_target"
        fi

        mkdir -p "$external_path"
        if [[ -d "$project_path" && ! -L "$project_path" ]]; then
            migrate_directory_contents "$project_path" "$external_path"
        elif [[ -L "$project_path" && "$USE_SUPERPOWERS_DOCS" -eq 1 ]] && symlink_points_to "$project_path" "$standard_external_path"; then
            if [[ -d "$standard_external_path" ]]; then
                migrate_directory_contents "$standard_external_path" "$external_path"
            fi
        elif [[ -L "$project_path" && "$USE_SUPERPOWERS_DOCS" -eq 0 ]] && symlink_points_to "$project_path" "$superpowers_target"; then
            mkdir -p "$standard_external_path"
            migrate_directory_contents "$superpowers_target" "$standard_external_path"
            DID_REVERSE_MIGRATION=1
        elif [[ "$USE_SUPERPOWERS_DOCS" -eq 0 && -d "$superpowers_target" && -n "$(find "$superpowers_target" -mindepth 1 -print -quit)" ]]; then
            mkdir -p "$standard_external_path"
            migrate_directory_contents "$superpowers_target" "$standard_external_path"
            DID_REVERSE_MIGRATION=1
        fi
        ensure_symlink_path "$project_path" "$external_path"
    done

    if [[ "$USE_SUPERPOWERS_DOCS" -eq 1 ]]; then
        while IFS= read -r -d '' ai_dir_path; do
            dir_name="$(basename "$ai_dir_path")"
            [[ "$dir_name" == "docs" || "$dir_name" == "plans" ]] && continue
            dynamic_target="$SUPERPOWERS_DOCS_ROOT/$dir_name"
            mkdir -p "$dynamic_target"
            if [[ -d "$ai_dir_path" && ! -L "$ai_dir_path" ]]; then
                migrate_directory_contents "$ai_dir_path" "$dynamic_target"
            elif [[ -L "$ai_dir_path" ]] && ! symlink_points_to "$ai_dir_path" "$dynamic_target"; then
                old_target="$(vault_realpath "$ai_dir_path")"
                if [[ -d "$old_target" && "$(vault_realpath "$dynamic_target")" != "$old_target" ]]; then
                    migrate_directory_contents "$old_target" "$dynamic_target"
                fi
            fi
            ensure_symlink_path "$ai_dir_path" "$dynamic_target"
        done < <(find "$PROJECT_AI_DIR" -mindepth 1 -maxdepth 1 \( -type d -o -type l \) -print0 2>/dev/null || true)
    else
        while IFS= read -r -d '' ai_dir_path; do
            dir_name="$(basename "$ai_dir_path")"
            [[ "$dir_name" == "specs" || "$dir_name" == "plans" ]] && continue
            dynamic_target="$VAULT_DIR/$dir_name"
            if [[ -L "$PROJECT_AI_DIR/$dir_name" ]] && symlink_points_to "$PROJECT_AI_DIR/$dir_name" "$SUPERPOWERS_DOCS_ROOT/$dir_name"; then
                mkdir -p "$dynamic_target"
                migrate_directory_contents "$SUPERPOWERS_DOCS_ROOT/$dir_name" "$dynamic_target"
                ensure_symlink_path "$PROJECT_AI_DIR/$dir_name" "$dynamic_target"
                DID_REVERSE_MIGRATION=1
            fi
        done < <(find "$SUPERPOWERS_DOCS_ROOT" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null || true)
    fi

    for name in "${MANAGED_DOC_FILES[@]}"; do
        write_file_if_missing "$EXTERNAL_DOCS_DIR/$name" "$TMP_DOCS_DIR/$name"
    done

    for name in "${ADAPTER_NAMES[@]}"; do
        external_path="$VAULT_DIR/$name"
        if [[ "$name" == "GEMINI.md" ]]; then
            ensure_symlink_path "$external_path" "$VAULT_DIR/AGENTS.md"
        else
            write_adapter_if_needed "$external_path" "$TMP_DIR/$name"
        fi
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

    if [[ "$PERSIST_USE_SUPERPOWERS_DOCS" -eq 1 ]]; then
        adapters_csv="$(printf '%s\n' "$AI_VAULT_CONFIG_ADAPTERS" | tr '\n' ',' | sed 's/,$//')"
        ai_vault_write_config \
            "$AI_VAULT_CONFIG_BASE_PATH" \
            "$adapters_csv" \
            "$AI_VAULT_CONFIG_RTK_INSTRUCTIONS" \
            "$AI_VAULT_CONFIG_SUPERPOWERS_INSTRUCTIONS" \
            "$AI_VAULT_CONFIG_CONTEXT_MODE_INSTRUCTIONS" \
            "$USE_SUPERPOWERS_DOCS" \
            "$AI_VAULT_CONFIG_ADHD_INSTRUCTIONS"
        AI_VAULT_CONFIG_USE_SUPERPOWERS_DOCS="$USE_SUPERPOWERS_DOCS"
    fi

}

detect_repo_facts
detect_all_plugins
if [[ "$AI_VAULT_CONFIG_SUPERPOWERS_INSTRUCTIONS" == "1" ]]; then
    prompt_superpowers_docs
fi
plan_ai_root
plan_ai_links
plan_ai_dynamic_subdirs
plan_project_adapter_links
plan_disabled_adapters
plan_git_exclude
render_adapters
render_managed_docs
plan_managed_docs
plan_adapter_content_changes
print_summary
require_confirmation_if_needed

if [[ "$HAS_CHANGES" -eq 0 ]]; then
    exit 0
fi

apply_changes

if [[ "$USE_SUPERPOWERS_DOCS" -eq 0 && "$DID_REVERSE_MIGRATION" -eq 1 && -d "$SUPERPOWERS_DOCS_ROOT" ]]; then
    printf '%s Reverted to standard vault paths. docs/superpowers/ left in place - remove manually if no longer needed.\n' "$AI_VAULT_WARNING_SYMBOL"
fi

printf '%s Initialization complete.\n' "$AI_VAULT_SUCCESS_SYMBOL"
