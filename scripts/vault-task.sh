#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CURRENT_DIR="$PWD"
while [[ "$CURRENT_DIR" != "/" && ! -d "$CURRENT_DIR/.ai" ]]; do
    CURRENT_DIR=$(dirname "$CURRENT_DIR")
done

AI_DIR="$CURRENT_DIR/.ai"
TASK_FILE="$AI_DIR/context/current-task.md"
TASK_TEMPLATE="$AI_DIR/context/current-task.template.md"

if [[ "$CURRENT_DIR" == "/" || ! -d "$AI_DIR" ]]; then
    echo "No .ai directory found in project tree. Run vault-init first." >&2
    exit 1
fi

usage() {
    cat <<'USAGE'
Usage:
  vault-task new [--mode plan|execute]
  vault-task quick "<goal>" [--mode plan|execute]
  vault-task show
  vault-task mode [plan|execute]
  vault-task done
  vault-task clear
  vault-task archive
USAGE
}

ensure_mode_frontmatter() {
    local mode_value="${1:-execute}"

    if grep -q '^mode:' "$TASK_FILE" 2>/dev/null; then
        sed -i '' -E "s/^mode:[[:space:]]*(plan|execute)/mode: $mode_value/" "$TASK_FILE"
        return
    fi

    local tmp
    tmp="$(mktemp)"
    {
        echo "<!-- AI-SHADOW-VAULT: MANAGED FILE -->"
        echo
        echo "---"
        echo "mode: $mode_value"
        echo "---"
        echo
        sed '/^<!-- AI-SHADOW-VAULT: MANAGED FILE -->/d' "$TASK_FILE"
    } > "$tmp"
    mv "$tmp" "$TASK_FILE"
}

reset_task() {
    if [[ -f "$TASK_TEMPLATE" ]]; then
        cp "$TASK_TEMPLATE" "$TASK_FILE"
    else
        cat > "$TASK_FILE" <<'EOF_TASK'
<!-- AI-SHADOW-VAULT: MANAGED FILE -->

---
mode: execute
---

# Current Task (Single Active Task)

## Goal
<one clear desired outcome>

## Context
<only facts needed for this task>

## Constraints
<scope limits, non-goals, hard requirements>

## Success Criteria
- <measurable outcome 1>
- <measurable outcome 2>

## Private Deliverables (Optional)
- none

---
Clear this file after completion.
Never accumulate history here.
EOF_TASK
    fi
}

print_warning() {
    echo "Warning: $1" >&2
}

validate_mode() {
    local mode="$1"
    [[ "$mode" == "plan" || "$mode" == "execute" ]]
}

collect_multiline() {
    local label="$1"
    local required="${2:-0}"
    local help_text="${3:-}"
    local lines=()
    local line=""

    while true; do
        lines=()
        echo "$label"
        if [[ -n "$help_text" ]]; then
            echo "Help: $help_text"
        fi
        echo "(finish with an empty line)"

        while IFS= read -r line; do
            [[ -z "$line" ]] && break
            lines+=("$line")
        done

        if [[ "$required" -eq 1 && "${#lines[@]}" -eq 0 ]]; then
            echo "This section is required. Please add at least one line."
            echo
            continue
        fi

        MULTILINE_RESULT="$(printf '%s\n' "${lines[@]:-}")"
        return
    done
}

to_bullets() {
    local source="$1"
    local result=""
    local line trimmed

    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        trimmed="$(printf '%s' "$line" | sed -E 's/^[[:space:]]*[-*]?[[:space:]]*//')"
        [[ -z "$trimmed" ]] && continue
        if [[ -n "$result" ]]; then
            result+=$'\n'
        fi
        result+="- $trimmed"
    done <<< "$source"

    BULLETS_RESULT="$result"
}

write_task_file() {
    local mode="$1"
    local goal="$2"
    local context="$3"
    local constraints="$4"
    local success_criteria="$5"
    local private_deliverables="$6"

    {
        echo "<!-- AI-SHADOW-VAULT: MANAGED FILE -->"
        echo
        echo "---"
        echo "mode: $mode"
        echo "---"
        echo
        echo "# Current Task (Single Active Task)"
        echo
        echo "## Goal"
        echo "$goal"
        echo
        echo "## Context"
        printf '%s\n' "$context"
        echo
        echo "## Constraints"
        printf '%s\n' "$constraints"
        echo
        echo "## Success Criteria"
        printf '%s\n' "$success_criteria"
        echo
        echo "## Private Deliverables (Optional)"
        printf '%s\n' "$private_deliverables"
        echo
        echo "---"
        echo "Clear this file after completion."
        echo "Never accumulate history here."
    } > "$TASK_FILE"
}

run_post_create_maintenance() {
    local warnings=0

    echo "Running post-create maintenance..."

    if [[ -x "$SCRIPT_DIR/vault-context.sh" ]]; then
        if "$SCRIPT_DIR/vault-context.sh" refresh >/dev/null 2>&1; then
            echo "- vault-context refresh: ok"
        else
            print_warning "vault-context refresh failed."
            warnings=$((warnings + 1))
        fi
    elif [[ -x "$SCRIPT_DIR/vault-ai-context-file.sh" ]]; then
        if "$SCRIPT_DIR/vault-ai-context-file.sh" >/dev/null 2>&1; then
            echo "- vault-context refresh (fallback): ok"
        else
            print_warning "vault-ai-context-file fallback failed."
            warnings=$((warnings + 1))
        fi
    else
        print_warning "No context refresh command found."
        warnings=$((warnings + 1))
    fi

    if [[ -x "$SCRIPT_DIR/vault-doctor.sh" ]]; then
        if "$SCRIPT_DIR/vault-doctor.sh" --fix >/dev/null 2>&1; then
            echo "- vault-doctor --fix: ok"
        else
            print_warning "vault-doctor --fix failed."
            warnings=$((warnings + 1))
        fi
    else
        print_warning "No vault-doctor command found."
        warnings=$((warnings + 1))
    fi

    if [[ "$warnings" -gt 0 ]]; then
        print_warning "Task was created, but post-create maintenance reported $warnings warning(s)."
    fi
}

command_new() {
    shift

    local default_mode="plan"
    local mode_input
    local mode
    local goal=""
    local context=""
    local constraints=""
    local success_criteria=""
    local private_deliverables=""

    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            --mode)
                default_mode="${2:-plan}"
                shift 2
                ;;
            *)
                echo "vault-task new is now interactive and does not accept goal arguments." >&2
                echo "Use: vault-task new [--mode plan|execute]" >&2
                echo "For automation use: vault-task quick \"<goal>\" [--mode plan|execute]" >&2
                exit 1
                ;;
        esac
    done

    if ! validate_mode "$default_mode"; then
        echo "Mode must be 'plan' or 'execute'." >&2
        exit 1
    fi

    if [[ ! -t 0 ]]; then
        echo "vault-task new requires interactive input (TTY)." >&2
        echo "Use vault-task quick \"<goal>\" for non-interactive usage." >&2
        exit 1
    fi

    echo "Creating a new task interactively."
    echo "Mode help: plan = define strategy first, execute = implementation-focused task."
    read -r -p "Mode [plan/execute] [$default_mode]: " mode_input
    mode="${mode_input:-$default_mode}"

    if ! validate_mode "$mode"; then
        echo "Mode must be 'plan' or 'execute'." >&2
        exit 1
    fi

    while [[ -z "$goal" ]]; do
        read -r -p "Goal (What you need to deliver?): " goal
        [[ -z "$goal" ]] && echo "Goal is required."
    done

    collect_multiline \
        "Context:" \
        1 \
        "Facts needed to execute safely (scope, flow, current state, dependencies)."
    context="$MULTILINE_RESULT"

    collect_multiline \
        "Constraints:" \
        1 \
        "Hard requirements, scope limits, non-goals, and rules that must not be violated."
    constraints="$MULTILINE_RESULT"

    collect_multiline \
        "Success Criteria (one item per line):" \
        1 \
        "Definition of Done: measurable outcomes that prove completion."
    to_bullets "$MULTILINE_RESULT"
    success_criteria="$BULLETS_RESULT"
    if [[ -z "$success_criteria" ]]; then
        echo "At least one success criterion is required." >&2
        exit 1
    fi

    collect_multiline \
        "Private Deliverables (Optional):" \
        0 \
        "Internal-only artifacts/paths/checklists (not shown to end users)."
    to_bullets "$MULTILINE_RESULT"
    private_deliverables="${BULLETS_RESULT:-- none}"

    write_task_file "$mode" "$goal" "$context" "$constraints" "$success_criteria" "$private_deliverables"

    echo "Created: $TASK_FILE"
    run_post_create_maintenance
}

command_quick() {
    shift

    local mode="execute"
    local goal=""
    local success_criteria="- <measurable check 1>
- <measurable check 2>"

    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            --mode)
                mode="${2:-execute}"
                shift 2
                ;;
            *)
                if [[ -n "$goal" ]]; then
                    goal="$goal $1"
                else
                    goal="$1"
                fi
                shift
                ;;
        esac
    done

    if [[ -z "$goal" ]]; then
        echo "Usage: vault-task quick \"<goal>\" [--mode plan|execute]" >&2
        exit 1
    fi

    if ! validate_mode "$mode"; then
        echo "Mode must be 'plan' or 'execute'." >&2
        exit 1
    fi

    write_task_file \
        "$mode" \
        "$goal" \
        "<facts needed to execute safely>" \
        "<scope limits, non-goals, hard requirements>" \
        "$success_criteria" \
        "- none"

    echo "Created: $TASK_FILE"
    run_post_create_maintenance
}

command_show() {
    if [[ -f "$TASK_FILE" ]]; then
        sed -n '1,240p' "$TASK_FILE"
    else
        echo "Missing task file: $TASK_FILE"
        exit 1
    fi
}

command_mode() {
    local target_mode="${2:-}"

    if [[ ! -f "$TASK_FILE" ]]; then
        reset_task
    fi

    if [[ -z "$target_mode" ]]; then
        grep '^mode:' "$TASK_FILE" | head -n 1 || echo "mode: execute"
        return
    fi

    if [[ "$target_mode" != "plan" && "$target_mode" != "execute" ]]; then
        echo "Mode must be 'plan' or 'execute'." >&2
        exit 1
    fi

    ensure_mode_frontmatter "$target_mode"
    echo "Updated mode to: $target_mode"
}

command_done() {
    "$SCRIPT_DIR/vault-ai-save.sh"
}

command_clear() {
    reset_task
    echo "Reset task file: $TASK_FILE"
}

command_archive() {
    "$SCRIPT_DIR/vault-ai-save.sh"
}

subcommand="${1:-show}"

case "$subcommand" in
    new)
        command_new "$@"
        ;;
    quick)
        command_quick "$@"
        ;;
    show)
        command_show
        ;;
    mode)
        command_mode "$@"
        ;;
    done)
        command_done
        ;;
    clear)
        command_clear
        ;;
    archive)
        command_archive
        ;;
    -h|--help|help)
        usage
        ;;
    *)
        echo "Unknown subcommand: $subcommand" >&2
        usage
        exit 1
        ;;
esac
