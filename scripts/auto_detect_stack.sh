#!/bin/bash

# AI Shadow Vault - Stack Auto-Detector
# Detects project technology stack and populates the Vault with relevant knowledge.

set -euo pipefail

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/vault-resolver.sh"

AI_VAULT=".ai"
DOCS_DIR="$AI_VAULT/docs/tech-stack"
CONTEXT_FILE="$AI_VAULT/context/tech-stack.md"
TEMPLATES_SKILLS_DIR=""
LARAVEL_PACK_HINT_ADDED=0

# --- Project Root Detection ---
# Find where the project root is (upwards search)
current_dir=$(pwd)
while [[ "$current_dir" != "/" ]]; do
    if [[ -f "$current_dir/composer.json" ]] || [[ -f "$current_dir/package.json" ]] || [[ -d "$current_dir/.git" ]]; then
        PROJECT_ROOT="$current_dir"
        break
    fi
    current_dir=$(dirname "$current_dir")
done

if [ -z "$PROJECT_ROOT" ]; then
    PROJECT_ROOT=$(pwd)
    echo -e "${YELLOW}⚠️  Could not detect project root (no composer.json/.git found). Using current directory: $PROJECT_ROOT${NC}"
else
    # Navigate to project root so all paths are relative to it
    cd "$PROJECT_ROOT" || exit 1
fi

# Locate Skills Templates
if [ -d "$SCRIPT_DIR/../templates/Skills" ]; then
    TEMPLATES_SKILLS_DIR="$SCRIPT_DIR/../templates/Skills"
elif [ -d "$(vault_shared_asset_path "templates/Skills")" ]; then
    TEMPLATES_SKILLS_DIR="$(vault_shared_asset_path "templates/Skills")"
# Fallback for when run from symlink or different structure
elif [ -d "$HOME/Sites/MySites/ai-shadow-vault/templates/Skills" ]; then
    TEMPLATES_SKILLS_DIR="$HOME/Sites/MySites/ai-shadow-vault/templates/Skills"
fi

if [ -z "$TEMPLATES_SKILLS_DIR" ]; then
    echo -e "${YELLOW}⚠️  Warning: Skills templates directory not found. Skipping knowledge copy.${NC}"
else
    echo -e "  Found templates at: $TEMPLATES_SKILLS_DIR"
fi

echo -e "${BLUE}🔍 Auto-detecting Tech Stack...${NC}"

# Ensure directories exist
mkdir -p "$DOCS_DIR"
mkdir -p "$(dirname "$CONTEXT_FILE")"

# Initialize Context File
echo "# Project Tech Stack" > "$CONTEXT_FILE"
echo "*Detected on $(date)*" >> "$CONTEXT_FILE"
echo "" >> "$CONTEXT_FILE"
echo "## Detected Technologies" >> "$CONTEXT_FILE"

# Helper to copy skill doc
copy_skill_doc() {
    local skill_file="$1"
    local dest_name="$2"
    
    if [ -f "$TEMPLATES_SKILLS_DIR/$skill_file" ]; then
        cp "$TEMPLATES_SKILLS_DIR/$skill_file" "$DOCS_DIR/$dest_name"
        echo -e "  ✅ Added knowledge base: ${GREEN}$dest_name${NC}"
    else
         # Silent fail or debug log if needed
         :
    fi
}

add_laravel_pack_hint() {
    local reason="$1"

    if [ "$LARAVEL_PACK_HINT_ADDED" -eq 1 ]; then
        return
    fi

    echo "- **Optional Pack**: Laravel pack recommended ($reason)." >> "$CONTEXT_FILE"
    echo "  Enable with: \`vault-ext enable laravel\`" >> "$CONTEXT_FILE"
    LARAVEL_PACK_HINT_ADDED=1
}

# --- PHP / Laravel Detection ---
if [ -f "composer.json" ]; then
    echo -e "  Found composer.json, analyzing PHP dependencies..."
    
    # PHP Version
    PHP_VERSION=$(grep '"php":' composer.json | head -n 1 | grep -o '[0-9]\.[0-9]' | head -n 1)
    if [ ! -z "$PHP_VERSION" ]; then
        echo "- **PHP**: $PHP_VERSION" >> "$CONTEXT_FILE"
    fi

    # Laravel
    if grep -q "laravel/framework" composer.json; then
        echo "- **Framework**: Laravel" >> "$CONTEXT_FILE"
        
        # Sail Detection
        if [ -f "sail" ] || [ -x "vendor/bin/sail" ]; then
            echo "- **Runner**: Laravel Sail (Docker)" >> "$CONTEXT_FILE"
            echo -e "  ✅ Detected ${GREEN}Laravel Sail${NC}. AI will prefer Sail commands."
        else
            echo "- **Runner**: Host (Native PHP/Composer)" >> "$CONTEXT_FILE"
        fi

        add_laravel_pack_hint "Laravel framework detected"
    fi

    # Laravel Nova
    if grep -q "laravel/nova" composer.json; then
        NOVA_VERSION=$(grep '"laravel/nova":' composer.json | grep -o '[0-9]\+' | head -n 1)
        echo "- **Admin Panel**: Laravel Nova (v$NOVA_VERSION detected)" >> "$CONTEXT_FILE"
        
        # Legacy Logic
        if [ "$NOVA_VERSION" == "3" ] || [ "$NOVA_VERSION" == "2" ]; then
            echo "- **Legacy Status**: Legacy Migration Active" >> "$CONTEXT_FILE"
            add_laravel_pack_hint "Legacy Nova migration detected"
        fi
    fi

    # Filament
    if grep -q "filament/filament" composer.json; then
        FILAMENT_VERSION=$(grep '"filament/filament":' composer.json | grep -o '[0-9]\+' | head -n 1)
        echo "- **Admin Panel**: Filament (v$FILAMENT_VERSION detected)" >> "$CONTEXT_FILE"
        
        add_laravel_pack_hint "Filament detected"
    fi

    # Livewire
    if grep -q "livewire/livewire" composer.json; then
        echo "- **Frontend Stack**: Livewire" >> "$CONTEXT_FILE"
        add_laravel_pack_hint "Livewire detected"
    fi
fi

# --- JS / Frontend Detection ---
if [ -f "package.json" ]; then
    echo -e "  Found package.json, analyzing JS dependencies..."

    # Vue
    if grep -q '"vue":' package.json; then
        VUE_VERSION=$(grep '"vue":' package.json | grep -o '[0-9]\+' | head -n 1)
        echo "- **Frontend Framework**: Vue.js (v$VUE_VERSION)" >> "$CONTEXT_FILE"
        copy_skill_doc "FRONTEND-EXPERT.md" "vue-frontend.md"
    fi

    # Tailwind
    if grep -q "tailwindcss" package.json; then
        echo "- **CSS Framework**: TailwindCSS" >> "$CONTEXT_FILE"
    fi
fi

echo "" >> "$CONTEXT_FILE"
echo "## Knowledge Base" >> "$CONTEXT_FILE"
echo "Relevant stack notes are recorded here. Optional pack recommendations are listed when applicable." >> "$CONTEXT_FILE"

echo -e "✅ Tech Stack detection complete. Summary saved to ${GREEN}$CONTEXT_FILE${NC}"
