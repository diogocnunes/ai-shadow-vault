#!/bin/bash

# AI Shadow Vault - Context Saver
# Archives completed work artifacts and keeps active context compact.

set -euo pipefail

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

CURRENT_DIR="$PWD"
while [[ "$CURRENT_DIR" != "/" && ! -d "$CURRENT_DIR/.ai" ]]; do
    CURRENT_DIR=$(dirname "$CURRENT_DIR")
done

AI_DIR="$CURRENT_DIR/.ai"

if [[ "$CURRENT_DIR" == "/" || ! -d "$AI_DIR" ]]; then
    echo -e "${YELLOW}⚠️  No .ai directory found in project tree.${NC}"
    exit 1
fi

TIMESTAMP=$(date +"%Y%m%d-%H%M")
ARCHIVE_DIR="$AI_DIR/archive"
LEGACY_ARCHIVE_DIR="$AI_DIR/context/archive"
PLAN_ARCHIVE_DIR="$ARCHIVE_DIR/plans"
TASK_ARCHIVE_DIR="$ARCHIVE_DIR/tasks"
INDEX_FILE="$AI_DIR/docs/INDEX.md"
CURRENT_TASK_FILE="$AI_DIR/context/current-task.md"
CURRENT_TASK_TEMPLATE="$AI_DIR/context/current-task.template.md"

mkdir -p "$ARCHIVE_DIR" "$PLAN_ARCHIVE_DIR" "$TASK_ARCHIVE_DIR" "$AI_DIR/docs"

migrate_legacy_archive_once() {
    local migrated=0

    [[ -d "$LEGACY_ARCHIVE_DIR" ]] || return 0

    while IFS= read -r -d '' legacy_file; do
        rel_path="${legacy_file#$LEGACY_ARCHIVE_DIR/}"
        target_path="$ARCHIVE_DIR/$rel_path"
        mkdir -p "$(dirname "$target_path")"
        if [[ ! -e "$target_path" ]]; then
            mv "$legacy_file" "$target_path"
            migrated=1
        fi
    done < <(find "$LEGACY_ARCHIVE_DIR" -type f -print0)

    if [[ "$migrated" -eq 1 ]]; then
        echo -e "📦 Migrated legacy archive files to ${GREEN}.ai/archive/${NC}"
    fi
}

status_is_completed() {
    local status_line="$1"
    local normalized_status

    [[ -n "$status_line" ]] || return 1

    normalized_status="$(printf '%s' "$status_line" | tr '[:upper:]' '[:lower:]')"
    if printf '%s' "$normalized_status" | grep -Eq 'complet|conclu[ií]d|done'; then
        return 0
    fi

    return 1
}

archive_completed_plans() {
    local archived_count=0
    local plan_file status_line base_name target_path suffix=1

    [[ -d "$AI_DIR/plans" ]] || return 0

    while IFS= read -r -d '' plan_file; do
        status_line="$(grep -im1 '^Status:[[:space:]]*' "$plan_file" || true)"
        if ! status_is_completed "$status_line"; then
            continue
        fi

        base_name="$(basename "$plan_file")"
        target_path="$PLAN_ARCHIVE_DIR/$base_name"

        while [[ -e "$target_path" ]]; do
            target_path="$PLAN_ARCHIVE_DIR/${base_name%.md}-$TIMESTAMP-$suffix.md"
            suffix=$((suffix + 1))
        done

        mv "$plan_file" "$target_path"
        echo -e "🧹 Archived plan: ${GREEN}archive/plans/$(basename "$target_path")${NC}"
        archived_count=$((archived_count + 1))
        suffix=1
    done < <(find "$AI_DIR/plans" -type f -name '*.md' -print0)

    if [[ "$archived_count" -eq 0 ]]; then
        echo -e "ℹ️  No completed plans found in .ai/plans."
    fi
}

task_file_has_active_content() {
    local file="$1"
    [[ -f "$file" ]] || return 1

    awk '
        /^## Goal$/ { in_goal=1; next }
        in_goal && /^## / { exit }
        in_goal && NF {
            if ($0 !~ /^<.*>$/) {
                found=1
            }
        }
        END { exit(found ? 0 : 1) }
    ' "$file"
}

archive_current_task_if_needed() {
    local archive_file

    if ! task_file_has_active_content "$CURRENT_TASK_FILE"; then
        echo -e "ℹ️  Current task is empty/template; nothing to archive."
        return
    fi

    archive_file="$TASK_ARCHIVE_DIR/task-$TIMESTAMP.md"
    cp "$CURRENT_TASK_FILE" "$archive_file"
    echo -e "📌 Archived current task: ${GREEN}archive/tasks/$(basename "$archive_file")${NC}"
}

reset_current_task_file() {
    if [[ -f "$CURRENT_TASK_TEMPLATE" ]]; then
        cp "$CURRENT_TASK_TEMPLATE" "$CURRENT_TASK_FILE"
        echo -e "♻️  Reset current task from template."
        return
    fi

    cat > "$CURRENT_TASK_FILE" <<'EOF_TASK'
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
    echo -e "♻️  Reset current task with default template."
}

refresh_agent_context() {
    local context_script
    context_script="$(dirname "$0")/vault-ai-context-file.sh"

    if [[ ! -x "$context_script" ]] && [[ -x "$(dirname "$0")/../scripts/vault-ai-context-file.sh" ]]; then
        context_script="$(dirname "$0")/../scripts/vault-ai-context-file.sh"
    fi

    if [[ -x "$context_script" ]]; then
        "$context_script" >/dev/null
        echo -e "🧭 Refreshed agent-context working state."
    else
        echo -e "${YELLOW}⚠️  Could not refresh agent context (script missing).${NC}"
    fi
}

rebuild_docs_index() {
    cat <<EOF_INDEX > "$INDEX_FILE"
# AI Knowledge Index
*Generated on $(date)*

## 📚 Documents
EOF_INDEX

    find "$AI_DIR/docs" -type f -name '*.md' ! -name 'INDEX.md' | sort | while read -r doc; do
        relative_path=${doc#$AI_DIR/docs/}
        title=$(grep -m 1 '^# ' "$doc" | sed 's/^# //')
        [[ -z "$title" ]] && title="$relative_path"
        echo "- [$title]($relative_path)" >> "$INDEX_FILE"
    done

    echo -e "✅ Index updated: ${GREEN}docs/INDEX.md${NC}"
}

echo -e "${BLUE}🛡️  Saving AI Shadow Vault Context...${NC}"

migrate_legacy_archive_once
archive_current_task_if_needed
archive_completed_plans
reset_current_task_file
refresh_agent_context
rebuild_docs_index

if [[ -x "$(dirname "$0")/vault-ai-stats.sh" ]]; then
    echo ""
    "$(dirname "$0")/vault-ai-stats.sh"
fi

echo -e "✨ Context preserved for next task."
