#!/bin/bash

# AI Shadow Vault - Doc Fetcher Agent
# Checks local docs before suggesting external searches.

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

DOC_NAME=$1
DOCS_DIR=".ai/docs"

if [ -z "$DOC_NAME" ]; then
    echo -e "${YELLOW}Usage: ./doc-fetcher.sh <doc-name-or-pattern>${NC}"
    exit 1
fi

echo -e "${BLUE}🔍 Searching for local documentation: $DOC_NAME...${NC}"

# Search for the doc
MATCH=$(find "$DOCS_DIR" -type f -name "*$DOC_NAME*" | head -n 1)

if [ -n "$MATCH" ]; then
    echo -e "${GREEN}✅ Found local documentation!${NC}"
    echo -e "Location: $MATCH"
    echo "------------------------------------------"
    head -n 20 "$MATCH"
    echo "..."
    echo "------------------------------------------"
    exit 0
else
    echo -e "${YELLOW}❌ No local documentation found for '$DOC_NAME'.${NC}"
    echo ""
    echo -e "${BLUE}📝 Create a new doc template? (y/n)${NC}"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        NEW_DOC="$DOCS_DIR/${DOC_NAME// /-}.md"
        cat <<EOF > "$NEW_DOC"
# Documentation: ${DOC_NAME}
Date: $(date +%Y-%m-%d)
Source: [Link or Tool]

## 📋 Overview
[Describe what this documentation covers]

## 💡 Key Findings
- 

## 🛠️ Usage / Implementation
```
// Code snippets or commands
```

## 🔗 Related
- 
EOF
        echo -e "${GREEN}✅ Template created at: $NEW_DOC${NC}"
    fi
fi
