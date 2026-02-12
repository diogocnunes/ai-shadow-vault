#!/bin/bash

# AI Shadow Vault - Expansion Initializer
# This script initializes the .ai/ structure for enhanced context management.

VAULT_ROOT="$HOME/.gemini-vault"
PROJECT_NAME=$(basename "$PWD")
PROJECT_VAULT="$VAULT_ROOT/$PROJECT_NAME"
AI_VAULT="$PROJECT_VAULT/.ai"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES_DIR="$SCRIPT_DIR/../templates"

echo "🛡️  Initializing AI Shadow Vault Expansion for: $PROJECT_NAME"

# 1. Create Vault structure
echo "📁 Creating Vault structure at $AI_VAULT..."
mkdir -p "$AI_VAULT/plans"
mkdir -p "$AI_VAULT/docs"
mkdir -p "$AI_VAULT/context/archive"
mkdir -p "$AI_VAULT/prompts"
mkdir -p "$AI_VAULT/cache"
mkdir -p "$AI_VAULT/agents"

# 2. Install base templates
echo "📄 Installing base templates..."
cp -n "$TEMPLATES_DIR/rules.md" "$AI_VAULT/rules.md"
cp -n "$TEMPLATES_DIR/session-template.md" "$AI_VAULT/session-template.md"

# 2.1 Install agents
echo "🤖 Installing AI agents..."
cp -n "$TEMPLATES_DIR/agents/"*.sh "$AI_VAULT/agents/"
chmod +x "$AI_VAULT/agents/"*.sh

# 3. Create local directory (replacing symlink approach)
if [ -d ".ai" ]; then
    echo "ℹ️  Directory .ai already exists."
else
    echo "📁 Creating local .ai directory..."
    mkdir -p ".ai/plans"
    mkdir -p ".ai/docs"
    mkdir -p ".ai/context/archive"
    mkdir -p ".ai/prompts"
    mkdir -p ".ai/cache"
    mkdir -p ".ai/agents"
fi

# 3.1 Ensure local files are present
echo "📄 Ensuring local templates and agents are present..."
cp -n "$TEMPLATES_DIR/rules.md" ".ai/rules.md"
cp -n "$TEMPLATES_DIR/session-template.md" ".ai/session-template.md"
cp -n "$TEMPLATES_DIR/agents/"*.sh ".ai/agents/"
chmod +x ".ai/agents/"*.sh

# 4. Claude Code Integration
echo "🤖 Setting up Claude Code integration..."
mkdir -p .claude
if [ -f ".claude/project-rules.md" ]; then
    echo "ℹ️  .claude/project-rules.md already exists."
else
    cp "$TEMPLATES_DIR/CLAUDE_PROJECT_RULES.md" ".claude/project-rules.md"
    echo "✅ Created .claude/project-rules.md"
fi

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
