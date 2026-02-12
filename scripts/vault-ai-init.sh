#!/bin/bash

# AI Shadow Vault - Expansion Initializer
# This script initializes the .ai/ structure for enhanced context management.

VAULT_ROOT="$HOME/.gemini-vault"
PROJECT_NAME=$(basename "$PWD")
PROJECT_VAULT="$VAULT_ROOT/$PROJECT_NAME"
AI_VAULT="$PROJECT_VAULT/.ai"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES_DIR="$SCRIPT_DIR/../templates"

# --- Project Root Detection ---
PROJECT_ROOT="$PWD"
while [[ "$PROJECT_ROOT" != "/" && ! -d "$PROJECT_ROOT/.git" && ! -f "$PROJECT_ROOT/composer.json" && ! -f "$PROJECT_ROOT/package.json" ]]; do
    PROJECT_ROOT=$(dirname "$PROJECT_ROOT")
done
if [[ "$PROJECT_ROOT" == "/" ]]; then PROJECT_ROOT="$PWD"; fi

echo "🛡️  Initializing AI Shadow Vault Expansion for: $PROJECT_NAME"
echo "📍 Project Root: $PROJECT_ROOT"

# 1. Create Vault structure (Local)
echo "📁 Creating local .ai directory..."
mkdir -p "$PROJECT_ROOT/.ai/plans"
mkdir -p "$PROJECT_ROOT/.ai/docs"
mkdir -p "$PROJECT_ROOT/.ai/context/archive"
mkdir -p "$PROJECT_ROOT/.ai/prompts"
mkdir -p "$PROJECT_ROOT/.ai/cache"
mkdir -p "$PROJECT_ROOT/.ai/agents"

# 2. Install base templates
echo "📄 Installing base templates..."
cp -n "$TEMPLATES_DIR/rules.md" "$PROJECT_ROOT/.ai/rules.md"
cp -n "$TEMPLATES_DIR/session-template.md" "$PROJECT_ROOT/.ai/session-template.md"

# 2.1 Install agents
echo "🤖 Installing AI agents..."
cp -n "$TEMPLATES_DIR/agents/"*.sh "$PROJECT_ROOT/.ai/agents/"
chmod +x "$PROJECT_ROOT/.ai/agents/"*.sh

# 4. Claude Code Integration
echo "🤖 Setting up Claude Code integration..."
mkdir -p "$PROJECT_ROOT/.claude"
cp "$TEMPLATES_DIR/CLAUDE_PROJECT_RULES.md" "$PROJECT_ROOT/.claude/project-rules.md"
echo "✅ Updated $PROJECT_ROOT/.claude/project-rules.md"

# 5. Git Exclude (Invisible Ignore)
echo "🙈 Updating .git/info/exclude (Silent Ignore)..."
if [ -d ".git" ]; then
    GIT_EXCLUDE=".git/info/exclude"
    touch "$GIT_EXCLUDE"
    
    FILES_TO_IGNORE=(".ai" ".ai/" ".claude" ".claude/" "GEMINI.md" "AGENTS.md" ".opencode.json" "copilot-instructions.md" ".cursorrules" ".windsurfrules" "cody-context.json" "cody-ignore")

    for file in "${FILES_TO_IGNORE[@]}"; do
        if ! grep -q "$file" "$GIT_EXCLUDE"; then
            echo "$file" >> "$GIT_EXCLUDE"
            echo "➕ Added $file to $GIT_EXCLUDE"
        fi
    done
else
    echo "⚠️  Not a git repository. Skipping .git/info/exclude update."
    
    # Fallback to local .gitignore if it exists
    if [ -f ".gitignore" ]; then
        echo "📝 Updating local .gitignore instead..."
        for file in "${FILES_TO_IGNORE[@]}"; do
            if ! grep -q "$file" ".gitignore"; then
                echo "$file" >> ".gitignore"
            fi
        done
    fi
fi

# 6. Global Git Safety Net
echo "🔒 Updating Global Git Safety Net..."
GLOBAL_IGNORE="$HOME/.gitignore_global"
touch "$GLOBAL_IGNORE"

for file in "${FILES_TO_IGNORE[@]}"; do
    if ! grep -q "$file" "$GLOBAL_IGNORE"; then
        echo "**/$file" >> "$GLOBAL_IGNORE"
        echo "➕ Added $file to $GLOBAL_IGNORE"
    fi
done

git config --global core.excludesfile "$GLOBAL_IGNORE"

# 7. Auto-Detect Stack & Populate Knowledge
if [ -f "$SCRIPT_DIR/auto_detect_stack.sh" ]; then
    echo ""
    "$SCRIPT_DIR/auto_detect_stack.sh"
fi

echo ""
echo "✨ AI Shadow Vault Expansion initialized successfully!"
echo "📍 Vault: $AI_VAULT"
echo "🔗 Local Link: .ai/"
echo "🤖 Claude Rules: .claude/project-rules.md"
echo ""
echo "Ready to code with deep context! 🚀"
