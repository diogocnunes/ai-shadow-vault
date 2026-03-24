#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES_DIR="$SCRIPT_DIR/../templates/.ai"
ROOT_TEMPLATES_DIR="$SCRIPT_DIR/../templates"

FIX_MODE=0
FIX_STRICT_MODE=0
STRICT_MODE=0
JSON_MODE=0
INTERACTIVE_MODE=0
EXPLAIN_CODE=""
STRICT_FIX_APPLIED=0
STRICT_FIX_BACKUP_DIR=""

CHECK_FILTER_RAW=""

while [[ "$#" -gt 0 ]]; do
    case "${1:-}" in
        --fix)
            FIX_MODE=1
            ;;
        --fix-strict)
            FIX_STRICT_MODE=1
            FIX_MODE=1
            ;;
        --strict)
            STRICT_MODE=1
            ;;
        --json)
            JSON_MODE=1
            ;;
        --interactive)
            INTERACTIVE_MODE=1
            ;;
        --check)
            if [[ -z "${2:-}" ]]; then
                echo "--check requires a value" >&2
                exit 1
            fi
            if [[ -z "$CHECK_FILTER_RAW" ]]; then
                CHECK_FILTER_RAW="$2"
            else
                CHECK_FILTER_RAW="$CHECK_FILTER_RAW,$2"
            fi
            shift
            ;;
        --explain)
            if [[ -z "${2:-}" ]]; then
                echo "--explain requires an issue code (for example: D003)." >&2
                exit 1
            fi
            EXPLAIN_CODE="$2"
            shift
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
    shift
done

if [[ "$INTERACTIVE_MODE" -eq 1 && "$JSON_MODE" -eq 1 ]]; then
    echo "--interactive cannot be combined with --json." >&2
    exit 1
fi

if [[ "$INTERACTIVE_MODE" -eq 1 && ( "$FIX_MODE" -eq 1 || "$FIX_STRICT_MODE" -eq 1 ) ]]; then
    echo "Use either --interactive or --fix/--fix-strict, not both." >&2
    exit 1
fi

print_issue_explanation() {
    local code="$1"

    case "$code" in
        D001)
            cat <<'EOF_EXPLAIN'
Code: D001
What: A required vNext directory is missing in `.ai/`.
Why: Canonical structure checks depend on these folders existing.
Impact if ignored: Commands may fail, and context lifecycle can drift.
Typical fix: Run `vault-doctor --fix` or `vault-init --optimize`.
EOF_EXPLAIN
            ;;
        D002)
            cat <<'EOF_EXPLAIN'
Code: D002
What: A required canonical file is missing.
Why: Core flows expect these managed files to exist.
Impact if ignored: Missing task/rules/context continuity and broken automation.
Typical fix: Run `vault-doctor --fix` or re-run `vault-init`.
EOF_EXPLAIN
            ;;
        D003)
            cat <<'EOF_EXPLAIN'
Code: D003
What: Legacy archive content exists under `.ai/context/archive`.
Why: vNext stores historical records under `.ai/archive`.
Impact if ignored: Mixed structure confusion and migration drift.
Typical fix: Run `vault-doctor --fix` or `vault-init --optimize`.
EOF_EXPLAIN
            ;;
        D010|D012)
            cat <<'EOF_EXPLAIN'
Code: D010/D012
What: Managed marker/header is missing in a managed file.
Why: Regeneration safety relies on managed-file markers.
Impact if ignored: Future refreshes may preserve stale content or skip updates.
Typical fix: Restore managed file from template or run optimized regeneration.
EOF_EXPLAIN
            ;;
        D020)
            cat <<'EOF_EXPLAIN'
Code: D020
What: Active context file exceeds compact size guidance.
Why: Large active files increase token waste and reduce model focus.
Impact if ignored: Lower quality responses and higher context overhead.
Typical fix: Trim active context, archive stale material, refresh generated context.
EOF_EXPLAIN
            ;;
        D021)
            cat <<'EOF_EXPLAIN'
Code: D021
What: A plan file is too large for active working context.
Why: Oversized plans are hard for agents to process reliably.
Impact if ignored: Planning noise, slower reasoning, and context inflation.
Typical fix: Split plan into smaller units and archive completed sections.
EOF_EXPLAIN
            ;;
        D030|D031)
            cat <<'EOF_EXPLAIN'
Code: D030/D031
What: Adapter files became too large or policy-like.
Why: Adapters must stay thin and non-authoritative.
Impact if ignored: Redundant/conflicting instructions and drift from canonical rules.
Typical fix: Move policy to `.ai/rules.md`, keep adapters minimal.
EOF_EXPLAIN
            ;;
        D040)
            cat <<'EOF_EXPLAIN'
Code: D040
What: Optional tooling is phrased as mandatory.
Why: Vault is tool-agnostic; optional tools must always have fallbacks.
Impact if ignored: Broken portability and confusing failures in minimal environments.
Typical fix: Replace hard requirement language with inline fallback behavior.
EOF_EXPLAIN
            ;;
        D050|D051)
            cat <<'EOF_EXPLAIN'
Code: D050/D051
What: `current-task.md` mode frontmatter is missing or invalid.
Why: Canonical plan/execute behavior depends on explicit task mode.
Impact if ignored: Agents can mis-handle execution mode and workflow intent.
Typical fix: Set `mode: plan` or `mode: execute` in frontmatter.
EOF_EXPLAIN
            ;;
        D090)
            cat <<'EOF_EXPLAIN'
Code: D090
What: Legacy vault structure is still present.
Why: Migration to vNext structure was not completed.
Impact if ignored: Ongoing mixed-state confusion and inconsistent tooling behavior.
Typical fix: Run `vault-init --optimize` to migrate.
EOF_EXPLAIN
            ;;
        *)
            echo "Unknown doctor code: $code" >&2
            echo "Tip: known codes include D001, D002, D003, D010, D020, D021, D030, D031, D040, D050, D051, D090." >&2
            return 1
            ;;
    esac
}

if [[ -n "$EXPLAIN_CODE" ]]; then
    print_issue_explanation "$EXPLAIN_CODE"
    exit $?
fi

CURRENT_DIR="$PWD"
while [[ "$CURRENT_DIR" != "/" && ! -d "$CURRENT_DIR/.ai" ]]; do
    CURRENT_DIR=$(dirname "$CURRENT_DIR")
done

PROJECT_ROOT="$CURRENT_DIR"
AI_DIR="$PROJECT_ROOT/.ai"

if [[ "$PROJECT_ROOT" == "/" || ! -d "$AI_DIR" ]]; then
    echo "No .ai directory found in project tree. Run vault-init first." >&2
    exit 1
fi

ISSUE_SEVERITY=()
ISSUE_CODE=()
ISSUE_MESSAGE=()
ISSUE_FIX_HINT=()
ISSUE_FIXABLE=()
ISSUE_FIX_ACTION=()
ISSUE_TARGET=()

LEGACY_HINT=0

add_issue() {
    ISSUE_SEVERITY+=("$1")
    ISSUE_CODE+=("$2")
    ISSUE_MESSAGE+=("$3")
    ISSUE_FIX_HINT+=("$4")
    ISSUE_FIXABLE+=("${5:-0}")
    ISSUE_FIX_ACTION+=("${6:-}")
    ISSUE_TARGET+=("${7:-}")
}

reset_issues() {
    ISSUE_SEVERITY=()
    ISSUE_CODE=()
    ISSUE_MESSAGE=()
    ISSUE_FIX_HINT=()
    ISSUE_FIXABLE=()
    ISSUE_FIX_ACTION=()
    ISSUE_TARGET=()
}

has_check_filter() {
    [[ -n "$CHECK_FILTER_RAW" ]]
}

should_run_check() {
    local check_name="$1"

    if ! has_check_filter; then
        return 0
    fi

    local item
    IFS=',' read -r -a filters <<< "$CHECK_FILTER_RAW"
    for item in "${filters[@]}"; do
        if [[ "$item" == "$check_name" ]]; then
            return 0
        fi
    done

    return 1
}

check_structure() {
    should_run_check structure || return 0

    local required_dirs=(
        "$AI_DIR/context"
        "$AI_DIR/plans"
        "$AI_DIR/docs"
        "$AI_DIR/skills"
        "$AI_DIR/archive"
    )

    local required_files=(
        "$AI_DIR/rules.md"
        "$AI_DIR/context/current-task.md"
        "$AI_DIR/context/project-context.md"
        "$AI_DIR/context/agent-context.md"
        "$AI_DIR/skills/ACTIVE_SKILLS.md"
    )

    local d f
    for d in "${required_dirs[@]}"; do
        if [[ ! -d "$d" ]]; then
            add_issue error D001 "Missing required directory: $d" "Create directory" 1 "Create missing directory" "$d"
        fi
    done

    for f in "${required_files[@]}"; do
        if [[ ! -f "$f" ]]; then
            add_issue error D002 "Missing required file: $f" "Regenerate managed file" 1 "Restore managed canonical file" "$f"
        fi
    done
}

check_legacy_archive() {
    should_run_check structure || should_run_check migration || return 0

    local legacy="$AI_DIR/context/archive"
    local modern="$AI_DIR/archive"

    if [[ -d "$legacy" ]] && find "$legacy" -type f -print -quit | grep -q .; then
        add_issue warning D003 "Legacy archive files found in $legacy" "Migrate to $modern" 1 "Migrate legacy archive to .ai/archive" "$legacy"
        LEGACY_HINT=1
    fi
}

check_managed_markers() {
    should_run_check managed-markers || return 0

    local managed_files=(
        "$AI_DIR/rules.md"
        "$AI_DIR/context/current-task.md"
        "$AI_DIR/context/project-context.md"
        "$AI_DIR/context/agent-context.md"
        "$AI_DIR/docs/vault-rules.md"
        "$PROJECT_ROOT/AGENTS.md"
        "$PROJECT_ROOT/CLAUDE.md"
        "$PROJECT_ROOT/GEMINI.md"
    )

    local f
    for f in "${managed_files[@]}"; do
        [[ -f "$f" ]] || continue
        if ! grep -q '^<!-- AI-SHADOW-VAULT: MANAGED FILE -->' "$f"; then
            add_issue warning D010 "Managed marker missing in: $f" "Restore managed header"
        fi
    done
}

check_inflation() {
    should_run_check inflation || return 0

    local file lines bytes label

    local targets=(
        "$AI_DIR/context/current-task.md|120|4096|current-task"
        "$AI_DIR/context/agent-context.md|80|3072|agent-context"
        "$AI_DIR/skills/ACTIVE_SKILLS.md|120|4096|active-skills"
    )

    local spec max_lines max_bytes fixable action
    for spec in "${targets[@]}"; do
        IFS='|' read -r file max_lines max_bytes label <<< "$spec"
        [[ -f "$file" ]] || continue
        lines=$(wc -l < "$file" | tr -d ' ')
        bytes=$(wc -c < "$file" | tr -d ' ')

        if (( lines > max_lines || bytes > max_bytes )); then
            fixable=0
            action="Manual trim required"
            if [[ "$label" == "agent-context" ]]; then
                fixable=1
                action="Regenerate compact agent-context working state"
            elif [[ "$label" == "active-skills" ]]; then
                fixable=1
                action="Rebuild compact ACTIVE_SKILLS index"
            fi

            add_issue warning D020 "$label is too large: ${lines} lines / ${bytes} bytes" "Trim active context or archive stale content" "$fixable" "$action" "$label"
        fi
    done

    if [[ -d "$AI_DIR/plans" ]]; then
        while IFS= read -r -d '' file; do
            lines=$(wc -l < "$file" | tr -d ' ')
            bytes=$(wc -c < "$file" | tr -d ' ')
            if (( lines > 250 || bytes > 10240 )); then
                add_issue warning D021 "Plan is too large: $file (${lines} lines / ${bytes} bytes)" "Split plan or archive completed sections"
            fi
        done < <(find "$AI_DIR/plans" -type f -name '*.md' -print0)
    fi
}

check_duplication() {
    should_run_check duplication || return 0

    local adapters=(
        "$PROJECT_ROOT/AGENTS.md"
        "$PROJECT_ROOT/CLAUDE.md"
        "$PROJECT_ROOT/GEMINI.md"
        "$PROJECT_ROOT/.cursorrules"
        "$PROJECT_ROOT/.windsurfrules"
    )

    local file lines
    for file in "${adapters[@]}"; do
        [[ -f "$file" ]] || continue
        lines=$(wc -l < "$file" | tr -d ' ')
        if (( lines > 80 )); then
            add_issue warning D030 "Adapter appears too long: $file (${lines} lines)" "Keep adapter files thin"
        fi
        if grep -q '^## 1) Authority' "$file" && [[ "$file" != "$AI_DIR/rules.md" ]]; then
            add_issue warning D031 "Policy-like section found in adapter: $file" "Move policy into .ai/rules.md"
        fi
    done
}

check_optional_tool_hard_dependency() {
    should_run_check capabilities || return 0

    local rules_file="$AI_DIR/rules.md"
    [[ -f "$rules_file" ]] || return 0

    if grep -Eiq 'mandatory.*(gemini|context7|rtk)' "$rules_file"; then
        add_issue error D040 "Optional tools appear as mandatory in rules.md" "Replace hard requirement with fallback wording"
    fi
}

fix_task_mode_missing() {
    local task_file="$AI_DIR/context/current-task.md"
    [[ -f "$task_file" ]] || return 1

    local tmp
    tmp="$(mktemp)"
    {
        echo "<!-- AI-SHADOW-VAULT: MANAGED FILE -->"
        echo
        echo "---"
        echo "mode: execute"
        echo "---"
        echo
        sed '/^<!-- AI-SHADOW-VAULT: MANAGED FILE -->/d' "$task_file"
    } > "$tmp"
    mv "$tmp" "$task_file"
}

fix_task_mode_invalid() {
    local task_file="$AI_DIR/context/current-task.md"
    [[ -f "$task_file" ]] || return 1

    if grep -q '^mode:' "$task_file"; then
        sed -i '' -E 's/^mode:[[:space:]]*.*/mode: execute/' "$task_file"
    else
        fix_task_mode_missing
    fi
}

check_task_mode() {
    should_run_check task-mode || return 0

    local task_file="$AI_DIR/context/current-task.md"
    [[ -f "$task_file" ]] || return 0

    local mode
    mode=$(grep '^mode:' "$task_file" | head -n 1 | awk -F': *' '{print $2}' || true)

    if [[ -z "$mode" ]]; then
        add_issue warning D050 "current-task.md has no mode frontmatter" "Set mode: plan|execute" 1 "Insert mode: execute frontmatter" "$task_file"
        return
    fi

    if [[ "$mode" != "plan" && "$mode" != "execute" ]]; then
        add_issue error D051 "Invalid task mode: $mode" "Use mode: plan or mode: execute" 1 "Normalize mode to execute" "$task_file"
    fi
}

check_legacy_message() {
    if [[ "$LEGACY_HINT" -eq 1 ]] && { should_run_check structure || should_run_check migration; }; then
        add_issue info D090 "Detected legacy vault structure. Run: vault-init --optimize to migrate to vNext." "Use optimize mode migration workflow"
    fi
}

collect_issues() {
    reset_issues
    LEGACY_HINT=0

    check_structure
    check_legacy_archive
    check_managed_markers
    check_inflation
    check_duplication
    check_optional_tool_hard_dependency
    check_task_mode
    check_legacy_message
}

fix_missing_file() {
    local file_path="$1"

    mkdir -p "$(dirname "$file_path")"

    case "$file_path" in
        "$AI_DIR/rules.md")
            cp "$TEMPLATES_DIR/rules.md" "$file_path" 2>/dev/null || return 1
            ;;
        "$AI_DIR/context/current-task.md")
            cp "$TEMPLATES_DIR/context/current-task.md" "$file_path" 2>/dev/null || return 1
            ;;
        "$AI_DIR/context/project-context.md")
            cp "$TEMPLATES_DIR/context/project-context.md" "$file_path" 2>/dev/null || return 1
            ;;
        "$AI_DIR/context/agent-context.md")
            cp "$TEMPLATES_DIR/context/agent-context.md" "$file_path" 2>/dev/null || return 1
            ;;
        "$AI_DIR/skills/ACTIVE_SKILLS.md")
            "$SCRIPT_DIR/build-active-skills.sh" "$PROJECT_ROOT" >/dev/null 2>&1 || return 1
            ;;
        *)
            return 1
            ;;
    esac

    return 0
}

fix_legacy_archive() {
    local legacy="$AI_DIR/context/archive"
    local modern="$AI_DIR/archive"

    [[ -d "$legacy" ]] || return 0

    mkdir -p "$modern"
    while IFS= read -r -d '' legacy_file; do
        rel_path="${legacy_file#$legacy/}"
        target_path="$modern/$rel_path"
        mkdir -p "$(dirname "$target_path")"
        [[ -e "$target_path" ]] || mv "$legacy_file" "$target_path"
    done < <(find "$legacy" -type f -print0)
}

fix_inflation_issue() {
    local label="$1"

    case "$label" in
        agent-context)
            "$SCRIPT_DIR/vault-ai-context-file.sh" >/dev/null 2>&1 || return 1
            ;;
        active-skills)
            "$SCRIPT_DIR/build-active-skills.sh" "$PROJECT_ROOT" >/dev/null 2>&1 || return 1
            ;;
        *)
            return 1
            ;;
    esac

    return 0
}

apply_issue_fix_by_index() {
    local idx="$1"
    local code="${ISSUE_CODE[$idx]}"
    local target="${ISSUE_TARGET[$idx]}"

    if [[ "${ISSUE_FIXABLE[$idx]}" != "1" ]]; then
        return 1
    fi

    case "$code" in
        D001)
            mkdir -p "$target"
            ;;
        D002)
            fix_missing_file "$target"
            ;;
        D003)
            fix_legacy_archive
            ;;
        D020)
            fix_inflation_issue "$target"
            ;;
        D050)
            fix_task_mode_missing
            ;;
        D051)
            fix_task_mode_invalid
            ;;
        *)
            return 1
            ;;
    esac

    return 0
}

post_fix_refresh() {
    "$SCRIPT_DIR/vault-ai-context-file.sh" >/dev/null 2>&1 || true
    "$SCRIPT_DIR/build-active-skills.sh" "$PROJECT_ROOT" >/dev/null 2>&1 || true
}

issue_counts() {
    local i
    ERROR_COUNT=0
    WARNING_COUNT=0
    INFO_COUNT=0

    for ((i=0; i<${#ISSUE_CODE[@]}; i++)); do
        case "${ISSUE_SEVERITY[$i]}" in
            error) ((ERROR_COUNT+=1)) ;;
            warning) ((WARNING_COUNT+=1)) ;;
            info) ((INFO_COUNT+=1)) ;;
        esac
    done
}

run_fix_mode() {
    local applied=0
    local idx

    for ((idx=0; idx<${#ISSUE_CODE[@]}; idx++)); do
        if [[ "${ISSUE_FIXABLE[$idx]}" == "1" ]]; then
            if apply_issue_fix_by_index "$idx"; then
                ((applied+=1))
            fi
        fi
    done

    if (( applied > 0 )); then
        post_fix_refresh
    fi
}

run_fix_strict_mode() {
    local adapter_specs=(
        "$ROOT_TEMPLATES_DIR/AGENTS.md|$PROJECT_ROOT/AGENTS.md"
        "$ROOT_TEMPLATES_DIR/CLAUDE.md|$PROJECT_ROOT/CLAUDE.md"
        "$ROOT_TEMPLATES_DIR/GEMINI.md|$PROJECT_ROOT/GEMINI.md"
        "$ROOT_TEMPLATES_DIR/.cursorrules|$PROJECT_ROOT/.cursorrules"
        "$ROOT_TEMPLATES_DIR/.windsurfrules|$PROJECT_ROOT/.windsurfrules"
    )

    local ts backup_dir spec src dst base replaced=0 backed_up=0
    ts="$(date +"%Y%m%d-%H%M%S")"
    backup_dir="$AI_DIR/archive/doctor-backups/adapters-$ts"

    for spec in "${adapter_specs[@]}"; do
        IFS='|' read -r src dst <<< "$spec"
        if [[ ! -f "$src" ]]; then
            echo "Strict fix failed: missing template $src" >&2
            return 1
        fi
    done

    mkdir -p "$backup_dir"

    for spec in "${adapter_specs[@]}"; do
        IFS='|' read -r src dst <<< "$spec"
        base="$(basename "$dst")"

        if [[ -e "$dst" || -L "$dst" ]]; then
            if cp -p "$dst" "$backup_dir/$base" 2>/dev/null; then
                ((backed_up+=1))
            elif cp "$dst" "$backup_dir/$base" 2>/dev/null; then
                ((backed_up+=1))
            fi
        fi

        mkdir -p "$(dirname "$dst")"
        cp "$src" "$dst"
        ((replaced+=1))
    done

    STRICT_FIX_APPLIED="$replaced"
    if (( backed_up > 0 )); then
        STRICT_FIX_BACKUP_DIR="$backup_dir"
    else
        rmdir "$backup_dir" >/dev/null 2>&1 || true
        STRICT_FIX_BACKUP_DIR=""
    fi

    post_fix_refresh
}

run_interactive_mode() {
    if [[ ! -t 0 ]]; then
        echo "--interactive requires a TTY. Use --fix for non-interactive runs." >&2
        exit 1
    fi

    local total="${#ISSUE_CODE[@]}"
    local idx answer applied=0

    if (( total == 0 )); then
        return
    fi

    echo "Found $total issues:"
    echo

    for ((idx=0; idx<total; idx++)); do
        printf '%d. %s\n' "$((idx + 1))" "${ISSUE_MESSAGE[$idx]}"

        if [[ "${ISSUE_FIXABLE[$idx]}" == "1" ]]; then
            echo "   Fix: ${ISSUE_FIX_ACTION[$idx]}"
            read -r -p "   Apply fix? [Y/n] " answer
            if [[ -z "$answer" || "$answer" =~ ^([yY][eE][sS]|[yY])$ ]]; then
                if apply_issue_fix_by_index "$idx"; then
                    echo "   ✓ applied"
                    ((applied+=1))
                else
                    echo "   ! failed to apply"
                fi
            else
                echo "   - skipped"
            fi
        else
            if [[ -n "${ISSUE_FIX_ACTION[$idx]}" ]]; then
                echo "   Fix: ${ISSUE_FIX_ACTION[$idx]}"
            else
                echo "   Fix: no safe automatic fix available"
            fi
        fi

        echo
    done

    if (( applied > 0 )); then
        post_fix_refresh
    fi
}

print_human_output() {
    local i

    if [[ "${#ISSUE_CODE[@]}" -eq 0 ]]; then
        echo "No issues found."
    else
        for ((i=0; i<${#ISSUE_CODE[@]}; i++)); do
            printf '[%s] %s %s\n' "${ISSUE_SEVERITY[$i]}" "${ISSUE_CODE[$i]}" "${ISSUE_MESSAGE[$i]}"
        done
    fi

    issue_counts

    echo
    echo "Summary: errors=$ERROR_COUNT warnings=$WARNING_COUNT info=$INFO_COUNT"

    if [[ "$FIX_MODE" -eq 1 ]]; then
        echo "Fix mode: applied safe automatic fixes where possible."
    fi

    if [[ "$FIX_STRICT_MODE" -eq 1 && "$STRICT_FIX_APPLIED" -gt 0 ]]; then
        echo "Fix-strict mode: replaced $STRICT_FIX_APPLIED adapter files with managed thin templates."
        if [[ -n "$STRICT_FIX_BACKUP_DIR" ]]; then
            echo "Backup: $STRICT_FIX_BACKUP_DIR"
        fi
    fi

    if [[ "$INTERACTIVE_MODE" -eq 1 ]]; then
        echo "Interactive mode: reviewed safe fixes issue-by-issue."
    fi

    if (( ERROR_COUNT > 0 )); then
        return 1
    fi

    if [[ "$STRICT_MODE" -eq 1 && "$WARNING_COUNT" -gt 0 ]]; then
        return 1
    fi

    return 0
}

json_escape() {
    sed 's/\\/\\\\/g; s/"/\\"/g'
}

print_json_output() {
    local i msg fix

    issue_counts

    echo '{'
    echo "  \"summary\": { \"errors\": $ERROR_COUNT, \"warnings\": $WARNING_COUNT, \"info\": $INFO_COUNT },"
    echo '  "issues": ['

    for ((i=0; i<${#ISSUE_CODE[@]}; i++)); do
        msg=$(printf '%s' "${ISSUE_MESSAGE[$i]}" | json_escape)
        fix=$(printf '%s' "${ISSUE_FIX_HINT[$i]}" | json_escape)
        printf '    { "severity": "%s", "code": "%s", "message": "%s", "fix": "%s" }' \
            "${ISSUE_SEVERITY[$i]}" "${ISSUE_CODE[$i]}" "$msg" "$fix"
        if (( i < ${#ISSUE_CODE[@]} - 1 )); then
            echo ','
        else
            echo
        fi
    done

    echo '  ]'
    echo '}'

    if (( ERROR_COUNT > 0 )); then
        return 1
    fi

    if [[ "$STRICT_MODE" -eq 1 && "$WARNING_COUNT" -gt 0 ]]; then
        return 1
    fi

    return 0
}

collect_issues

if [[ "$INTERACTIVE_MODE" -eq 1 ]]; then
    run_interactive_mode
    collect_issues
fi

if [[ "$FIX_MODE" -eq 1 ]]; then
    run_fix_mode
    collect_issues
fi

if [[ "$FIX_STRICT_MODE" -eq 1 ]]; then
    run_fix_strict_mode
    collect_issues
fi

if [[ "$JSON_MODE" -eq 1 ]]; then
    print_json_output
else
    print_human_output
fi
