#!/bin/bash

# AI Shadow Vault - Context Resumer
# Displays current working context from canonical vault files.

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

ARCHIVE_DIR="$AI_DIR/archive"
LEGACY_ARCHIVE_DIR="$AI_DIR/context/archive"

echo -e "${BLUE}🔄 Resuming AI Shadow Vault Context${NC}"
echo "------------------------------------------"

if [[ -f "$AI_DIR/context/current-task.md" ]]; then
    echo -e "${BLUE}🎯 Current Task:${NC}"
    awk '
        /^## Goal$/ { capture=1; next }
        capture && /^## / { exit }
        capture && NF { print "  - " $0; exit }
    ' "$AI_DIR/context/current-task.md" || true
fi

echo ""

echo -e "${BLUE}📝 Working State:${NC}"
if [[ -f "$AI_DIR/context/agent-context.md" ]]; then
    grep -E '^- (Current focus|Active plan refs|Open blockers/risks|Active branch):' "$AI_DIR/context/agent-context.md" | sed 's/^- /  - /' || true
else
    echo "  - No agent-context file found."
fi

echo ""

echo -e "${BLUE}📦 Recent Archive:${NC}"
if [[ -d "$ARCHIVE_DIR" ]]; then
    find "$ARCHIVE_DIR" -type f | sort | tail -n 5 | sed "s|$AI_DIR/|  - |" || true
elif [[ -d "$LEGACY_ARCHIVE_DIR" ]]; then
    find "$LEGACY_ARCHIVE_DIR" -type f | sort | tail -n 5 | sed "s|$AI_DIR/|  - |" || true
else
    echo "  - No archive entries found."
fi

echo "------------------------------------------"
echo -e "💡 ${YELLOW}Tip:${NC} Use ${GREEN}vault-ai-context${NC} to refresh working-state context."
