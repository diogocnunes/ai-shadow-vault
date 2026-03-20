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
PLAN_ARCHIVE_DIR="$AI_DIR/context/archive/plans"

status_is_completed() {
    local status_line="$1"
    local normalized_status

    [ -n "$status_line" ] || return 1

    normalized_status="$(printf '%s' "$status_line" | tr '[:upper:]' '[:lower:]')"
    if printf '%s' "$normalized_status" | grep -Eq 'complet|conclu[ií]d|done'; then
        return 0
    fi

    return 1
}

archive_completed_plans() {
    local archived_count=0
    local plan_file status_line base_name target_path suffix=1
    local -a archived_names=()

    [ -d "$AI_DIR/plans" ] || return 0

    while IFS= read -r -d '' plan_file; do
        status_line="$(grep -im1 '^Status:[[:space:]]*' "$plan_file" || true)"
        if ! status_is_completed "$status_line"; then
            continue
        fi

        mkdir -p "$PLAN_ARCHIVE_DIR"
        base_name="$(basename "$plan_file")"
        target_path="$PLAN_ARCHIVE_DIR/$base_name"

        while [ -e "$target_path" ]; do
            target_path="$PLAN_ARCHIVE_DIR/${base_name%.md}-$TIMESTAMP-$suffix.md"
            suffix=$((suffix + 1))
        done

        mv "$plan_file" "$target_path"
        archived_names+=("$(basename "$target_path")")
        archived_count=$((archived_count + 1))
        suffix=1
    done < <(find "$AI_DIR/plans" -type f -name "*.md" -print0)

    if [ "$archived_count" -gt 0 ]; then
        echo -e "🧹 Archived completed plans: ${GREEN}$archived_count${NC}"
        for base_name in "${archived_names[@]}"; do
            echo -e "   - ${GREEN}context/archive/plans/$base_name${NC}"
        done
    else
        echo -e "ℹ️  No completed plans found in .ai/plans."
    fi
}

echo -e "${BLUE}🛡️  Saving AI Shadow Vault Context...${NC}"

# 1. Archive Session
# If there's an active session file (session.md) in the root of .ai, archive it
if [ ! -f "$AI_DIR/session.md" ]; then
    echo -e "${YELLOW}ℹ️  No active session.md found.${NC}"
    echo -ne "Would you like to create a quick summary now? (y/N): "
    read -r response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        if [ -f "$AI_DIR/agents/context-update.sh" ]; then
            bash "$AI_DIR/agents/context-update.sh"
        else
            echo -e "${BLUE}📝 Enter session goal/summary (one line):${NC}"
            read -r summary
            cat <<EOF > "$AI_DIR/session.md"
# AI Session Summary
Date: $(date)
Goal: $summary

## 📦 Changes
- Automated session capture
EOF
        fi
    fi
fi

if [ -f "$AI_DIR/session.md" ]; then
    ARCHIVE_NAME="session-$TIMESTAMP.md"
    mv "$AI_DIR/session.md" "$AI_DIR/context/archive/$ARCHIVE_NAME"
    echo -e "📦 Session archived: ${GREEN}context/archive/$ARCHIVE_NAME${NC}"
else
    echo -e "ℹ️  Session skipped (no file to archive)."
fi

archive_completed_plans

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
