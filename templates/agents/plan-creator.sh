#!/bin/bash

# AI Shadow Vault - Plan Creator Agent
# Generates a new architectural plan.

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PLAN_NAME=$1
PLANS_DIR=".ai/plans"

if [ -z "$PLAN_NAME" ]; then
    echo -e "${YELLOW}Usage: ./plan-creator.sh "Plan Title"${NC}"
    exit 1
fi

FILE_NAME=$(echo "$PLAN_NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | sed 's/[^a-z0-9-]//g')
PLAN_PATH="$PLANS_DIR/$FILE_NAME.md"

if [ -f "$PLAN_PATH" ]; then
    echo -e "${YELLOW}⚠️  Plan already exists: $PLAN_PATH${NC}"
    exit 1
fi

echo -e "${BLUE}🏗️  Creating Architectural Plan: $PLAN_NAME...${NC}"

cat <<EOF > "$PLAN_PATH"
# Plan: $PLAN_NAME
Status: 🔄 In Progress
Created: $(date +%Y-%m-%d)

## 📖 Context
[Why is this plan needed? What is the current situation?]

## 🎯 Objectives
- [ ] 

## 🏗️ Architectural Design
[Describe patterns, services, or models to be used]

## 🛠️ Implementation Tasks
1. [ ] 
2. [ ] 

## 🧪 Verification & Tests
- [ ] 

## 📅 Timeline & Dependencies
- 
EOF

echo -e "${GREEN}✅ Architectural plan created at: $PLAN_PATH${NC}"
${EDITOR:-nano} "$PLAN_PATH"
