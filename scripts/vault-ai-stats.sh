#!/bin/bash

# AI Shadow Vault - Stats Calculator
# Displays usage statistics and estimated token savings.

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

AI_DIR=".ai"

if [ ! -d "$AI_DIR" ]; then
    echo -e "${YELLOW}⚠️  No .ai directory found. Run vault-ai-init first.${NC}"
    exit 1
fi

echo -e "${BLUE}📊 AI Shadow Vault Statistics${NC}"
echo "------------------------------------------"

# 1. Disk Size
DISK_SIZE=$(du -sh "$AI_DIR" | cut -f1)
echo -e "📁 Total Size on Disk: ${GREEN}$DISK_SIZE${NC}"

# 2. Document Count
DOC_COUNT=$(find "$AI_DIR/docs" -type f -name "*.md" | wc -l | xargs)
CACHE_COUNT=$(find "$AI_DIR/cache" -type f | wc -l | xargs)
PLAN_COUNT=$(find "$AI_DIR/plans" -type f -name "*.md" | wc -l | xargs)

echo -e "📄 Knowledge Docs:    ${GREEN}$DOC_COUNT${NC}"
echo -e "💾 Cached Responses:  ${GREEN}$CACHE_COUNT${NC}"
echo -e "📝 Active Plans:      ${GREEN}$PLAN_COUNT${NC}"

# 3. Estimated Token Savings
# Rough estimate: 1 KB of text ≈ 250 tokens
# We'll calculate based on the total size of docs and cache
TOTAL_KB=$(du -sk "$AI_DIR" | cut -f1)
ESTIMATED_TOKENS=$((TOTAL_KB * 250))
ESTIMATED_SAVINGS=$(echo "scale=2; $ESTIMATED_TOKENS / 1000" | bc)

echo -e "💰 Est. Token Savings: ${GREEN}${ESTIMATED_TOKENS} tokens (~${ESTIMATED_SAVINGS}K)${NC}"

# 4. Cache Age
if [ "$CACHE_COUNT" -gt 0 ]; then
    # Get the date of the oldest file in cache
    OLDEST_CACHE=$(find "$AI_DIR/cache" -type f -exec stat -f "%m %N" {} + | sort -n | head -1 | cut -f1 -d' ')
    if [[ "$OSTYPE" == "darwin"* ]]; then
        OLDEST_DATE=$(date -r "$OLDEST_CACHE" "+%Y-%m-%d")
    else
        OLDEST_DATE=$(date -d "@$OLDEST_CACHE" "+%Y-%m-%d")
    fi
    echo -e "⏳ Cache Age:         Started on ${YELLOW}$OLDEST_DATE${NC}"
else
    echo -e "⏳ Cache Age:         ${YELLOW}Empty${NC}"
fi

echo "------------------------------------------"
