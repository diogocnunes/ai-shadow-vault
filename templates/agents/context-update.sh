#!/bin/bash

# AI Shadow Vault - Context Updater Agent
# Quick access to current working-state context.

BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

CONTEXT_FILE=".ai/context/agent-context.md"

if [ ! -f "$CONTEXT_FILE" ]; then
    echo -e "${YELLOW}ℹ️  No agent-context.md found. Generating with vault-ai-context...${NC}"
    if command -v vault-ai-context >/dev/null 2>&1; then
        vault-ai-context >/dev/null || true
    fi
fi

if [ ! -f "$CONTEXT_FILE" ]; then
    echo -e "${YELLOW}⚠️  Context file still missing. Create .ai first with vault-init.${NC}"
    exit 1
fi

echo -e "${BLUE}📝 Opening working-state context...${NC}"
${EDITOR:-nano} "$CONTEXT_FILE"
