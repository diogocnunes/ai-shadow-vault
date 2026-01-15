#!/bin/bash

# Cores para o output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

INSTALL_PATH="$HOME/.ai-shadow-vault"

echo -e "${BLUE}🔄 Checking for AI Shadow Vault updates...${NC}"

cd "$INSTALL_PATH" || exit

# 1. Verificar se há atualizações no servidor
git fetch origin main -q

LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse @{u})

if [ "$LOCAL" = "$REMOTE" ]; then
    echo -e "${GREEN}✨ You are already on the latest version!${NC}"
    exit 0
fi

# 2. Se houver atualizações, mostrar o que mudou (Release Notes)
echo -e "${YELLOW}🎁 New update found! What's new:${NC}"
echo "------------------------------------------"
git --no-pager log HEAD..origin/main --oneline --pretty=format:"%C(yellow)▶ %s %C(reset)(%cr)"
echo -e "\n------------------------------------------"

# 3. Fazer o pull
echo -e "${BLUE}📥 Downloading and applying updates...${NC}"
git pull origin main -q

echo -e "${GREEN}✅ Update successful!${NC}"
echo -e "${YELLOW}💡 Please run 'source ~/.zshrc' or restart terminal to apply changes.${NC}"
