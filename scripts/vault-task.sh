#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TASK_COMPILER_LIB="$SCRIPT_DIR/lib/task-compiler.sh"

if [[ -f "$TASK_COMPILER_LIB" ]]; then
    # shellcheck source=/dev/null
    source "$TASK_COMPILER_LIB"
fi

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
  vault-task compile [--stdin|--input "<text>"|--file <path>] [--mode plan|execute] [--output-lang en|pt|auto] [--enrich conservative|repo-aware] [--format markdown|json] [--apply]
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

## Validation Instructions
- <how this task should be validated>

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
    local validation_instructions="$6"
    local private_deliverables="$7"

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
        echo "## Validation Instructions"
        printf '%s\n' "$validation_instructions"
        echo
        echo "## Private Deliverables (Optional)"
        printf '%s\n' "$private_deliverables"
        echo
        echo "---"
        echo "Clear this file after completion."
        echo "Never accumulate history here."
    } > "$TASK_FILE"
}

render_task_markdown() {
    local mode="$1"
    local goal="$2"
    local context="$3"
    local constraints="$4"
    local success_criteria="$5"
    local validation_instructions="$6"
    local private_deliverables="$7"

    cat <<EOF_TASK
<!-- AI-SHADOW-VAULT: MANAGED FILE -->

---
mode: $mode
---

# Current Task (Single Active Task)

## Goal
$goal

## Context
$context

## Constraints
$constraints

## Success Criteria
$success_criteria

## Validation Instructions
$validation_instructions

## Private Deliverables (Optional)
$private_deliverables

---
Clear this file after completion.
Never accumulate history here.
EOF_TASK
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
    local validation_instructions=""
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
        "Validation Instructions (one item per line):" \
        1 \
        "How to verify task completion (commands, browser/tooling steps, and expected checks)."
    to_bullets "$MULTILINE_RESULT"
    validation_instructions="$BULLETS_RESULT"
    if [[ -z "$validation_instructions" ]]; then
        echo "At least one validation instruction is required." >&2
        exit 1
    fi

    collect_multiline \
        "Private Deliverables (Optional):" \
        0 \
        "Internal-only artifacts/paths/checklists (not shown to end users)."
    to_bullets "$MULTILINE_RESULT"
    private_deliverables="${BULLETS_RESULT:-- none}"

    write_task_file "$mode" "$goal" "$context" "$constraints" "$success_criteria" "$validation_instructions" "$private_deliverables"

    echo "Created: $TASK_FILE"
    run_post_create_maintenance
}

command_quick() {
    shift

    local mode="execute"
    local goal=""
    local success_criteria="- <measurable check 1>
- <measurable check 2>"
    local validation_instructions="- <validation step 1>
- <validation step 2>"

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
        "$validation_instructions" \
        "- none"

    echo "Created: $TASK_FILE"
    run_post_create_maintenance
}

json_escape() {
    awk '
        BEGIN { first = 1 }
        {
            gsub(/\\/, "\\\\")
            gsub(/"/, "\\\"")
            if (!first) {
                printf "\\n"
            }
            printf "%s", $0
            first = 0
        }
    ' <<< "$1"
}

strip_bullets() {
    sed -E 's/^[[:space:]]*-[[:space:]]*//'
}

json_array_from_lines() {
    local source="$1"
    local first=1
    local line escaped

    printf '['
    while IFS= read -r line; do
        line="$(printf '%s' "$line" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')"
        [[ -n "$line" ]] || continue
        escaped="$(json_escape "$line")"
        if [[ "$first" -eq 1 ]]; then
            printf '"%s"' "$escaped"
            first=0
        else
            printf ',"%s"' "$escaped"
        fi
    done <<< "$source"
    printf ']'
}

command_compile() {
    shift

    local mode="execute"
    local input_arg=""
    local input_file=""
    local read_stdin=0
    local apply_changes=0
    local output_lang="en"
    local enrich_mode="repo-aware"
    local output_format="markdown"
    local raw_input=""
    local stdin_payload=""
    local file_payload=""

    local goal context constraints success validation private_deliverables
    local metadata_input_language metadata_output_language metadata_task_type diagnostics references

    if ! declare -f vtc_compile_text >/dev/null 2>&1; then
        echo "Task compiler library not available: $TASK_COMPILER_LIB" >&2
        exit 1
    fi

    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            --mode)
                mode="${2:-execute}"
                shift 2
                ;;
            --stdin)
                read_stdin=1
                shift
                ;;
            --input)
                if [[ -n "${2:-}" ]]; then
                    if [[ -n "$input_arg" ]]; then
                        input_arg="$input_arg"$'\n'"$2"
                    else
                        input_arg="$2"
                    fi
                fi
                shift 2
                ;;
            --file)
                input_file="${2:-}"
                shift 2
                ;;
            --output-lang)
                output_lang="${2:-en}"
                shift 2
                ;;
            --enrich)
                enrich_mode="${2:-repo-aware}"
                shift 2
                ;;
            --format)
                output_format="${2:-markdown}"
                shift 2
                ;;
            --apply)
                apply_changes=1
                shift
                ;;
            *)
                if [[ -n "$input_arg" ]]; then
                    input_arg="$input_arg $1"
                else
                    input_arg="$1"
                fi
                shift
                ;;
        esac
    done

    if ! validate_mode "$mode"; then
        echo "Mode must be 'plan' or 'execute'." >&2
        exit 1
    fi

    if [[ "$output_lang" != "en" && "$output_lang" != "pt" && "$output_lang" != "auto" ]]; then
        echo "Output language must be one of: en, pt, auto." >&2
        exit 1
    fi

    if [[ "$enrich_mode" != "conservative" && "$enrich_mode" != "repo-aware" ]]; then
        echo "Enrich mode must be one of: conservative, repo-aware." >&2
        exit 1
    fi

    if [[ "$output_format" != "markdown" && "$output_format" != "json" ]]; then
        echo "Format must be one of: markdown, json." >&2
        exit 1
    fi

    if [[ -n "$input_file" ]]; then
        if [[ ! -f "$input_file" ]]; then
            echo "Input file not found: $input_file" >&2
            exit 1
        fi
        file_payload="$(cat "$input_file")"
    fi

    if [[ "$read_stdin" -eq 1 ]]; then
        stdin_payload="$(cat)"
    fi

    if [[ -n "$input_arg" ]]; then
        raw_input="$input_arg"
    fi

    if [[ -n "$file_payload" ]]; then
        if [[ -n "$raw_input" ]]; then
            raw_input="$raw_input"$'\n'"$file_payload"
        else
            raw_input="$file_payload"
        fi
    fi

    if [[ -n "$stdin_payload" ]]; then
        if [[ -n "$raw_input" ]]; then
            raw_input="$raw_input"$'\n'"$stdin_payload"
        else
            raw_input="$stdin_payload"
        fi
    fi

    raw_input="$(vtc_trim "$raw_input")"
    if [[ -z "$raw_input" ]]; then
        echo "No input provided. Use --input, --file, --stdin, or positional text." >&2
        exit 1
    fi

    vtc_compile_text "$raw_input" "$output_lang" "$enrich_mode"

    goal="$VTC_GOAL"
    context="$VTC_CONTEXT"
    constraints="$VTC_CONSTRAINTS"
    success="$VTC_SUCCESS"
    validation="$VTC_VALIDATION"
    private_deliverables="$VTC_PRIVATE"
    diagnostics="$VTC_DIAGNOSTICS"
    references="$VTC_REFERENCES"
    metadata_input_language="$VTC_INPUT_LANGUAGE"
    metadata_output_language="$VTC_OUTPUT_LANGUAGE"
    metadata_task_type="$VTC_TASK_TYPE"

    if [[ "$apply_changes" -eq 1 ]]; then
        write_task_file "$mode" "$goal" "$context" "$constraints" "$success" "$validation" "$private_deliverables"
    fi

    if [[ "$output_format" == "json" ]]; then
        printf '{'
        printf '"mode":"%s",' "$(json_escape "$mode")"
        printf '"goal":"%s",' "$(json_escape "$goal")"
        printf '"context":%s,' "$(json_array_from_lines "$(strip_bullets <<< "$context")")"
        printf '"constraints":%s,' "$(json_array_from_lines "$(strip_bullets <<< "$constraints")")"
        printf '"success_criteria":%s,' "$(json_array_from_lines "$(strip_bullets <<< "$success")")"
        printf '"validation_instructions":%s,' "$(json_array_from_lines "$(strip_bullets <<< "$validation")")"
        printf '"private_deliverables":%s,' "$(json_array_from_lines "$(strip_bullets <<< "$private_deliverables")")"
        printf '"references":%s,' "$(json_array_from_lines "$references")"
        printf '"diagnostics":%s,' "$(json_array_from_lines "$(strip_bullets <<< "$diagnostics")")"
        printf '"metadata":{'
        printf '"input_language":"%s",' "$(json_escape "$metadata_input_language")"
        printf '"output_language":"%s",' "$(json_escape "$metadata_output_language")"
        printf '"task_type":"%s",' "$(json_escape "$metadata_task_type")"
        printf '"enrich_mode":"%s"' "$(json_escape "$enrich_mode")"
        printf '}'
        printf '}\n'
    else
        render_task_markdown "$mode" "$goal" "$context" "$constraints" "$success" "$validation" "$private_deliverables"
    fi

    if [[ "$apply_changes" -eq 1 ]]; then
        echo "Created: $TASK_FILE"
        run_post_create_maintenance
    fi

    if [[ -n "$diagnostics" && "$diagnostics" != "- " ]]; then
        {
            echo "Compiler diagnostics:"
            printf '%s\n' "$diagnostics"
        } >&2
    fi
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
    compile)
        command_compile "$@"
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
