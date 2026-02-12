#!/bin/bash

# AI Shadow Vault - Session Saver
# Archives active sessions and updates the knowledge index.

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Find project root with .ai directory
CURRENT_DIR="$PWD"
while [[ "$CURRENT_DIR" != "/" && ! -d "$CURRENT_DIR/.ai" ]]; do
    CURRENT_DIR=$(dirname "$CURRENT_DIR")
done

AI_DIR="$CURRENT_DIR/.ai"

if [[ "$CURRENT_DIR" == "/" || ! -d "$AI_DIR" ]]; then
    echo -e "${YELLOW}⚠️  No .ai directory found in project tree.${NC}"
    exit 1
fi

TIMESTAMP=$(date +"%Y%m%d-%H%M")
INDEX_FILE="$AI_DIR/docs/INDEX.md"

echo -e "${BLUE}🛡️  Saving AI Shadow Vault Context...${NC}"

# 1. Archive Session
# If there's an active session file (session.md) in the root of .ai, archive it
if [ -f "$AI_DIR/session.md" ]; then
    ARCHIVE_NAME="session-$TIMESTAMP.md"
    mv "$AI_DIR/session.md" "$AI_DIR/context/archive/$ARCHIVE_NAME"
    echo -e "📦 Session archived: ${GREEN}context/archive/$ARCHIVE_NAME${NC}"
else
    echo -e "ℹ️  No active session.md found to archive."
fi

# 2. Update Knowledge Index (INDEX.md)
echo -e "🗂️  Updating Document Index..."
cat <<EOF > "$INDEX_FILE"
# AI Knowledge Index
*Generated on $(date)*

## 📚 Documents
EOF

find "$AI_DIR/docs" -type f -name "*.md" ! -name "INDEX.md" | sort | while read -r doc; do
    RELATIVE_PATH=${doc#$AI_DIR/docs/}
    TITLE=$(grep -m 1 "^# " "$doc" | sed 's/^# //')
    [ -z "$TITLE" ] && TITLE=$RELATIVE_PATH
    echo "- [$TITLE]($RELATIVE_PATH)" >> "$INDEX_FILE"
done

echo -e "✅ Index updated: ${GREEN}docs/INDEX.md${NC}"

# 3. Show Stats
echo ""
bash "$(dirname "$0")/vault-ai-stats.sh"

echo -e "✨ Context preserved. Ready for the next session! 🚀"
