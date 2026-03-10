#!/bin/bash

# AI Shadow Vault - Agent Context File Generator
# Generates a promptable context artifact for tools without clipboard integration.

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

mkdir -p "$(dirname "$CONTEXT_FILE")"

{
    echo "# Agent Context"
    echo
    echo "> Generated automatically by AI Shadow Vault. Regenerate with \`$SCRIPT_DIR/vault-ai-context-file.sh\` or \`cc\`."
    echo
    echo "- Project: $PROJECT_SLUG"
    if [[ -n "$PROJECT_KEY" ]]; then
        echo "- Repository: $PROJECT_KEY"
    fi
    echo "- Generated: $(date)"
    echo
    echo "## Session Recap"

    LAST_SESSION=""
    if [[ -d "$AI_DIR/context/archive" ]]; then
        LAST_SESSION=$(ls -t "$AI_DIR/context/archive" 2>/dev/null | head -n 1 || true)
    fi

    if [[ -n "$LAST_SESSION" && -f "$AI_DIR/context/archive/$LAST_SESSION" ]]; then
        echo "- Last archive: $LAST_SESSION"
        grep -v "^# " "$AI_DIR/context/archive/$LAST_SESSION" | grep -v "^Date: " | sed '/^$/d' | head -n 10 | sed 's/^/  /' || true
    else
        echo "- No archived sessions found."
    fi

    echo
    echo "## Active Plans"
    if [[ -d "$AI_DIR/plans" ]] && find "$AI_DIR/plans" -type f -name "*.md" -print -quit | grep -q .; then
        find "$AI_DIR/plans" -type f -name "*.md" -exec basename {} \; | sort | sed 's/^/- /'
    else
        echo "- No active plans found."
    fi

    echo
    echo "## Local Docs"
    if [[ -f "$AI_DIR/docs/INDEX.md" ]]; then
        grep "^- " "$AI_DIR/docs/INDEX.md" | head -n 5 || true
    elif [[ -d "$AI_DIR/docs" ]] && find "$AI_DIR/docs" -maxdepth 1 -type f -name "*.md" -print -quit | grep -q .; then
        find "$AI_DIR/docs" -maxdepth 1 -type f -name "*.md" -exec basename {} \; | head -n 5 | sed 's/^/- /'
    else
        echo "- No local docs indexed yet."
    fi

    echo
    echo "## Rules"
    if [[ -f "$AI_DIR/rules.md" ]]; then
        cat "$AI_DIR/rules.md"
    else
        echo "No .ai/rules.md found."
    fi
} > "$CONTEXT_FILE"

echo -e "${GREEN}✅ Agent context generated:${NC} $CONTEXT_FILE"
