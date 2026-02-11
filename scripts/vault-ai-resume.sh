#!/bin/bash

# AI Shadow Vault - Session Resumer
# Displays context from the last session and available resources.

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

AI_DIR=".ai"

if [ ! -d "$AI_DIR" ]; then
    echo -e "${YELLOW}⚠️  No .ai directory found.${NC}"
    exit 1
fi

echo -e "${BLUE}🔄 Resuming AI Shadow Vault Context${NC}"
echo "------------------------------------------"

# 1. Show Last Archived Session
LAST_SESSION=$(ls -t "$AI_DIR/context/archive" | head -n 1)
if [ -n "$LAST_SESSION" ]; then
    echo -e "${BLUE}📝 Last Session:${NC} $LAST_SESSION"
    echo -e "${YELLOW}Context Recap:${NC}"
    # Show the first 10 lines of the last session, skipping the title
    grep -v "^# " "$AI_DIR/context/archive/$LAST_SESSION" | grep -v "^Date: " | head -n 10 | sed 's/^/  /'
    echo "  ..."
else
    echo -e "ℹ️  No archived sessions found."
fi

echo ""

# 2. List Active Plans
echo -e "${BLUE}🎯 Active Plans:${NC}"
PLANS=$(find "$AI_DIR/plans" -type f -name "*.md" | wc -l | xargs)
if [ "$PLANS" -gt 0 ]; then
    find "$AI_DIR/plans" -type f -name "*.md" -exec basename {} \; | sed 's/^/  ✅ /'
else
    echo -e "  ${YELLOW}No active plans found.${NC}"
fi

echo ""

# 3. List Key Documents
echo -e "${BLUE}📚 Available Documents:${NC}"
if [ -f "$AI_DIR/docs/INDEX.md" ]; then
    grep "^- " "$AI_DIR/docs/INDEX.md" | head -n 5 | sed 's/^- /  📄 /'
    DOC_TOTAL=$(grep "^- " "$AI_DIR/docs/INDEX.md" | wc -l | xargs)
    [ "$DOC_TOTAL" -gt 5 ] && echo "  ... ($DOC_TOTAL total)"
else
    find "$AI_DIR/docs" -type f -name "*.md" -maxdepth 1 | head -n 5 | xargs -n 1 basename | sed 's/^/  📄 /'
fi

echo "------------------------------------------"
echo -e "🚀 Run ${GREEN}vault-ai-save${NC} when you finish your next task!"
