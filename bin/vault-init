#!/bin/bash

VAULT_ROOT="$HOME/.gemini-vault"
PROJECT_NAME=$(basename "$PWD")
PROJECT_VAULT="$VAULT_ROOT/$PROJECT_NAME"

echo "🛡️  Initializing AI Shadow Vault for: $PROJECT_NAME"

# 1. Create Vault structure
mkdir -p "$PROJECT_VAULT"

# 2. Copy templates if they don't exist
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cp -n "$SCRIPT_DIR/../templates/AGENTS.md" "$PROJECT_VAULT/AGENTS.md"
cp -n "$SCRIPT_DIR/../templates/GEMINI.md" "$PROJECT_VAULT/GEMINI.md"
# Novo: Suporte ao Copilot e Universal AI
cp -n "$SCRIPT_DIR/../templates/copilot-instructions.md" "$PROJECT_VAULT/copilot-instructions.md"
cp -n "$SCRIPT_DIR/../templates/CLAUDE.md" "$PROJECT_VAULT/CLAUDE.md"
cp -n "$SCRIPT_DIR/../templates/.cursorrules" "$PROJECT_VAULT/.cursorrules"
cp -n "$SCRIPT_DIR/../templates/.windsurfrules" "$PROJECT_VAULT/.windsurfrules"
cp -n "$SCRIPT_DIR/../templates/cody-context.json" "$PROJECT_VAULT/cody-context.json"
cp -n "$SCRIPT_DIR/../templates/cody-ignore" "$PROJECT_VAULT/cody-ignore"

echo "✅ Vault directory created at: $PROJECT_VAULT"

# 3. Laravel Boost Detection & Installation
if [ -f "composer.json" ]; then
    # Check if Laravel is in the dependencies
    if grep -q '"laravel/framework"' composer.json; then
        echo ""
        echo "🔍 Laravel project detected!"
        echo -n "Would you like to install Laravel Boost? (y/n): "
        read -r response

        if [[ "$response" =~ ^[Yy]$ ]]; then
            echo "📦 Installing Laravel Boost..."

            # Install Laravel Boost via composer
            if composer require "laravel/boost:^2.0" --dev; then
                echo "✅ Laravel Boost package installed."

                # Run the Boost installer
                echo "🚀 Running Laravel Boost installer..."
                if php artisan boost:install; then
                    echo "✅ Laravel Boost installed successfully!"
                else
                    echo "⚠️  Laravel Boost installer failed. Please check the errors above."
                fi
            else
                echo "⚠️  Failed to install Laravel Boost package. Please check the errors above."
            fi
        else
            echo "⏭️  Skipping Laravel Boost installation."
        fi
    fi
fi

# 4. Global Git Safety Net
echo "🔒 Configuring Global Git Safety Net..."
GLOBAL_IGNORE="$HOME/.gitignore_global"
touch "$GLOBAL_IGNORE"

# Added GEMINI.md to the ignore list (+ Laravel Boost and Universal AI files)
FILES_TO_IGNORE=("GEMINI.md" ".opencode-context.md" "AGENTS.md" ".opencode.json" ".mcp.json" "CLAUDE.md" "boost.json" ".ai/" "copilot-instructions.md" ".cursorrules" ".windsurfrules" "cody-context.json" "cody-ignore" ".github/" ".cody/" ".claude/")

for file in "${FILES_TO_IGNORE[@]}"; do
    if ! grep -q "$file" "$GLOBAL_IGNORE"; then
        echo "**/$file" >> "$GLOBAL_IGNORE"
    fi
done

git config --global core.excludesfile "$GLOBAL_IGNORE"
echo "✅ Global Git Safety Net updated."