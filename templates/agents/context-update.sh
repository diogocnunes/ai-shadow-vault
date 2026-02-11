#!/bin/bash

# AI Shadow Vault - Context Updater Agent
# Quick access to current session context.

BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

SESSION_FILE=".ai/session.md"

if [ ! -f "$SESSION_FILE" ]; then
    echo -e "${YELLOW}ℹ️  No active session.md found. Creating from template...${NC}"
    if [ -f ".ai/session-template.md" ]; then
        cp ".ai/session-template.md" "$SESSION_FILE"
    else
        echo -e "${YELLOW}⚠️  Template not found. Creating empty session.md${NC}"
        touch "$SESSION_FILE"
    fi
fi

echo -e "${BLUE}📝 Opening current context for update...${NC}"
${EDITOR:-nano} "$SESSION_FILE"
