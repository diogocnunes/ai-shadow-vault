#!/bin/bash

# AI Shadow Vault - Agent Context File Generator
# Generates a compact working-state context for cross-session continuity.

set -euo pipefail

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/vault-resolver.sh"

CURRENT_DIR="$PWD"
while [[ "$CURRENT_DIR" != "/" && ! -d "$CURRENT_DIR/.ai" ]]; do
    CURRENT_DIR=$(dirname "$CURRENT_DIR")
done

AI_DIR="$CURRENT_DIR/.ai"

if [[ "$CURRENT_DIR" == "/" || ! -d "$AI_DIR" ]]; then
    echo -e "${YELLOW}⚠️  No .ai directory found in project tree.${NC}"
    exit 1
fi

CONTEXT_FILE="$AI_DIR/context/agent-context.md"
PROJECT_ROOT="$CURRENT_DIR"
PROJECT_KEY="$(vault_resolve_project_key "$PROJECT_ROOT" || true)"
PROJECT_SLUG="$(vault_resolve_project_slug "$PROJECT_ROOT")"
ARCHIVE_DIR="$AI_DIR/archive"
LEGACY_ARCHIVE_DIR="$AI_DIR/context/archive"
ACTIVE_TASK_FILE="$AI_DIR/context/current-task.md"

mkdir -p "$(dirname "$CONTEXT_FILE")"
mkdir -p "$ARCHIVE_DIR"

if [[ -d "$LEGACY_ARCHIVE_DIR" ]]; then
    LAST_ARCHIVE=$(ls -t "$LEGACY_ARCHIVE_DIR" 2>/dev/null | head -n 1 || true)
else
    LAST_ARCHIVE=$(ls -t "$ARCHIVE_DIR" 2>/dev/null | head -n 1 || true)
fi

CURRENT_BRANCH="$(git -C "$PROJECT_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'unknown')"

extract_current_task_field() {
    local field="$1"
    local file="$2"

    [[ -f "$file" ]] || return 0

    awk -v field="$field" '
        $0 == "## " field { capture=1; next }
        capture && /^## / { exit }
        capture && NF { print; exit }
    ' "$file"
}

TASK_GOAL="$(extract_current_task_field "Goal" "$ACTIVE_TASK_FILE" || true)"
TASK_CONTEXT="$(extract_current_task_field "Context" "$ACTIVE_TASK_FILE" || true)"
TASK_MODE="$(grep '^mode:' "$ACTIVE_TASK_FILE" 2>/dev/null | head -n 1 | awk -F': *' '{print $2}' || true)"

if [[ -z "$TASK_GOAL" || "$TASK_GOAL" == "<one clear desired outcome>" || "$TASK_GOAL" == "<clear desired outcome>" ]]; then
    CURRENT_FOCUS="No active task defined"
else
    CURRENT_FOCUS="$TASK_GOAL"
fi

if [[ -z "$TASK_CONTEXT" || "$TASK_CONTEXT" == "<only facts needed for this task>" || "$TASK_CONTEXT" == "<facts needed to execute safely>" ]]; then
    BLOCKERS="none"
else
    BLOCKERS="See current-task context"
fi

ACTIVE_PLAN_REFS="none"
if [[ -d "$AI_DIR/plans" ]]; then
    PLAN_LIST="$(find "$AI_DIR/plans" -maxdepth 1 -type f -name '*.md' -exec basename {} \; | sort | head -n 3 | paste -sd ', ' - || true)"
    if [[ -n "$PLAN_LIST" ]]; then
        ACTIVE_PLAN_REFS="$PLAN_LIST"
    fi
fi

SKILL_IDS="none"
if [[ -f "$AI_DIR/skills/ACTIVE_SKILLS.md" ]]; then
    SKILL_IDS="$(grep -E '^- `[^`]+`' "$AI_DIR/skills/ACTIVE_SKILLS.md" | sed -E 's/^- `([^`]+)`/\1/' | head -n 5 | paste -sd ', ' - || true)"
    [[ -z "$SKILL_IDS" ]] && SKILL_IDS="index present"
fi

{
    echo "<!-- AI-SHADOW-VAULT: MANAGED FILE -->"
    echo
    echo "# Agent Context (Working-State Continuity)"
    echo
    echo "- Project: $PROJECT_SLUG"
    if [[ -n "$PROJECT_KEY" ]]; then
        echo "- Repository: $PROJECT_KEY"
    fi
    echo "- Last updated: $(date +'%Y-%m-%d %H:%M:%S %Z')"
    if [[ -n "$TASK_MODE" ]]; then
        echo "- Task mode: $TASK_MODE"
    fi
    echo "- Active branch: $CURRENT_BRANCH"
    echo "- Current focus: $CURRENT_FOCUS"
    echo "- Active plan refs: $ACTIVE_PLAN_REFS"
    echo "- Open blockers/risks: $BLOCKERS"
    echo "- Active skills: $SKILL_IDS"
    if [[ -n "$LAST_ARCHIVE" ]]; then
        echo "- Last archive entry: $LAST_ARCHIVE"
    fi
    echo
    echo "Rules:"
    echo "- Keep short and meaningful."
    echo "- No policy duplication."
    echo "- No historical log accumulation."
} > "$CONTEXT_FILE"

echo -e "${GREEN}✅ Agent context refreshed:${NC} $CONTEXT_FILE"
