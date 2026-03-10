#!/bin/bash

# AI Shadow Vault - Expansion Initializer
# This script initializes the .ai/ structure for enhanced context management.

set -euo pipefail

# Resolve SCRIPT_DIR correctly, handling symlinks
SOURCE=${BASH_SOURCE[0]}
while [ -L "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR=$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )
  SOURCE=$(readlink "$SOURCE")
  [[ $SOURCE != /* ]] && SOURCE=$DIR/$SOURCE # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
SCRIPT_DIR=$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )

source "$SCRIPT_DIR/lib/vault-resolver.sh"

DATA_ROOT="$(vault_ensure_data_root)"
PROJECT_ROOT="$(vault_resolve_project_root "$PWD")"
PROJECT_SLUG="$(vault_resolve_project_slug "$PROJECT_ROOT")"
PROJECT_VAULT="$(vault_resolve_project_vault "$PROJECT_ROOT")"
AI_VAULT="$PROJECT_VAULT/.ai"
TEMPLATES_DIR="$SCRIPT_DIR/../templates"

echo "🛡️  Initializing AI Shadow Vault Expansion for: $PROJECT_SLUG"
echo "📍 Project Root: $PROJECT_ROOT"
echo "📦 Data Root: $DATA_ROOT"

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
# cp -n "$TEMPLATES_DIR/rules.md" "$PROJECT_ROOT/.ai/rules.md"  <-- Removed static copy
cp -n "$TEMPLATES_DIR/session-template.md" "$PROJECT_ROOT/.ai/session-template.md"

# 2.1 Run dynamic configuration for rules.md
if [ -s "$PROJECT_ROOT/.ai/rules.md" ]; then
    echo "✅ Rules file already exists. Skipping configuration."
elif [ -f "$SCRIPT_DIR/vault-ai-configurator.sh" ]; then
    (
        cd "$PROJECT_ROOT"
        bash "$SCRIPT_DIR/vault-ai-configurator.sh"
    )
else
    cp -n "$TEMPLATES_DIR/rules.md" "$PROJECT_ROOT/.ai/rules.md"
fi

# 2.2 Install agents
echo "🤖 Installing AI agents..."
cp -n "$TEMPLATES_DIR/agents/"*.sh "$PROJECT_ROOT/.ai/agents/"
chmod +x "$PROJECT_ROOT/.ai/agents/"*.sh

# Create the 'plan' symlink for easy access
ln -sf ".ai/agents/plan-creator.sh" "$PROJECT_ROOT/plan"
echo "🔗 Symlink 'plan' created for easy access."

# 4. Claude Code Integration
echo "🤖 Setting up Claude Code integration..."
mkdir -p "$PROJECT_ROOT/.claude"
cp "$TEMPLATES_DIR/CLAUDE_PROJECT_RULES.md" "$PROJECT_ROOT/.claude/project-rules.md"
echo "✅ Updated $PROJECT_ROOT/.claude/project-rules.md"

# 5. Git Exclude (Invisible Ignore)
echo "🙈 Updating .git/info/exclude (Silent Ignore)..."
FILES_TO_IGNORE=(
    ".ai"
    ".ai/"
    ".ai/context/agent-context.md"
    ".claude"
    ".claude/"
    "GEMINI.md"
    "AGENTS.md"
    ".opencode.json"
    "copilot-instructions.md"
    ".cursorrules"
    ".windsurfrules"
    "cody-context.json"
    "cody-ignore"
    "plan"
)

if [ -d "$PROJECT_ROOT/.git" ]; then
    GIT_EXCLUDE="$PROJECT_ROOT/.git/info/exclude"
    touch "$GIT_EXCLUDE"
    for file in "${FILES_TO_IGNORE[@]}"; do
        if ! grep -q "$file" "$GIT_EXCLUDE"; then
            echo "$file" >> "$GIT_EXCLUDE"
            echo "➕ Added $file to $GIT_EXCLUDE"
        fi
    done
else
    echo "⚠️  Not a git repository. Skipping .git/info/exclude update."
    
    # Fallback to local .gitignore if it exists
    if [ -f "$PROJECT_ROOT/.gitignore" ]; then
        echo "📝 Updating local .gitignore instead..."
        for file in "${FILES_TO_IGNORE[@]}"; do
            if ! grep -q "$file" "$PROJECT_ROOT/.gitignore"; then
                echo "$file" >> "$PROJECT_ROOT/.gitignore"
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
    echo "🔍 Launching stack auto-detection..."
    bash "$SCRIPT_DIR/auto_detect_stack.sh"
else
    echo "⚠️  Could not find auto_detect_stack.sh in $SCRIPT_DIR"
fi

echo ""
echo "✨ AI Shadow Vault Expansion initialized successfully!"
echo "📍 Vault: $AI_VAULT"
echo "🔗 Local Link: .ai/"
echo "🤖 Claude Rules: .claude/project-rules.md"
echo ""
echo "💡 To activate the interactive skills used by the installed commands:"
echo "   Run 'vault-skills' and select the ones you need."
echo ""
echo "Ready to code with deep context! 🚀"
