#!/bin/bash

# AI Shadow Vault - Project Configurator (V2.1)
# Detects project tech stack and dynamically generates context files.

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

TEMPLATES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../templates" && pwd)"
AI_DIR=".ai"
PROJECT_NAME=$(basename "$PWD")

# Output Files
RULES_FILE="$AI_DIR/rules.md"
GEMINI_FILE="GEMINI.md"
CLAUDE_FILE="CLAUDE.md"

# Templates
T_RULES="$TEMPLATES_DIR/rules.template.md"
T_GEMINI="$TEMPLATES_DIR/GEMINI.template.md"
T_CLAUDE="$TEMPLATES_DIR/CLAUDE.template.md"

echo -e "${BLUE}⚙️  Configuring AI Shadow Vault Dynamic Context...${NC}"

# Default values
PHP_VERSION="8.3"
FRAMEWORK="Laravel"
FRAMEWORK_VERSION="11"
ADMIN_PANEL="None"
ADMIN_VERSION=""
ADMIN_DIR="app/Filament"
FRONTEND_STACK="Vue.js"
FRONTEND_VERSION="3"
UI_LIBRARY="None"
DATABASE_STACK="MySQL / Redis"
ARCHITECTURE_TYPE="Monolithic"
BUILD_COMMAND="npm run build"
DEV_COMMAND="npm run dev"
TEST_COMMAND="php artisan test"
TEST_WATCH_COMMAND="php artisan test --watch"
PRIMARY_LANGUAGE="PHP / TypeScript"
FORMATTING_TOOLS="Laravel Pint / ESLint"

# 1. Detection Logic
if [ -f "composer.json" ]; then
    echo -e "  🔍 Analyzing composer.json..."
    
    DETECTED_PHP=$(grep '"php":' composer.json | head -n 1 | grep -o '[0-9]\.[0-9]' | head -n 1)
    [ ! -z "$DETECTED_PHP" ] && PHP_VERSION=$DETECTED_PHP
    
    if grep -q "laravel/framework" composer.json; then
        FRAMEWORK="Laravel"
        DETECTED_LV=$(grep '"laravel/framework":' composer.json | grep -o '[0-9]\+' | head -n 1)
        [ ! -z "$DETECTED_LV" ] && FRAMEWORK_VERSION=$DETECTED_LV
    fi

    if grep -q "livewire/livewire" composer.json; then
        FRONTEND_STACK="Livewire (TALL Stack)"
        UI_LIBRARY="TailwindCSS"
        FORMATTING_TOOLS="Laravel Pint / Tailwind CSS"
    fi
    
    if grep -q "laravel/nova" composer.json; then
        ADMIN_PANEL="Laravel Nova"
        ADMIN_VERSION=$(grep '"laravel/nova":' composer.json | grep -o '[0-9]\+' | head -n 1)
        ADMIN_DIR="app/Nova"
    elif grep -q "filament/filament" composer.json; then
        ADMIN_PANEL="Filament"
        ADMIN_VERSION=$(grep '"filament/filament":' composer.json | grep -o '[0-9]\+' | head -n 1)
        ADMIN_DIR="app/Filament"
        FRONTEND_STACK="Livewire (Filament)"
    fi

    if grep -q "pestphp/pest" composer.json; then
        TEST_COMMAND="./vendor/bin/pest"
        TEST_WATCH_COMMAND="./vendor/bin/pest --watch"
    fi
fi

if [ -f "package.json" ]; then
    echo -e "  🔍 Analyzing package.json..."
    if grep -q '"vue":' package.json; then
        FRONTEND_STACK="Vue.js"
        FRONTEND_VERSION=$(grep '"vue":' package.json | grep -o '[0-9]\+' | head -n 1)
        if grep -q "primevue" package.json; then UI_LIBRARY="PrimeVue";
        elif grep -q "quasar" package.json; then UI_LIBRARY="Quasar"; fi
    elif grep -q '"react":' package.json; then
        FRONTEND_STACK="React"
        FRONTEND_VERSION=$(grep '"react":' package.json | grep -o '[0-9]\+' | head -n 1)
        PRIMARY_LANGUAGE="TypeScript / React"
    fi
    if grep -q "tailwindcss" package.json && [ "$UI_LIBRARY" == "None" ]; then UI_LIBRARY="TailwindCSS"; fi
    if grep -q "vite" package.json; then BUILD_COMMAND="npm run build"; DEV_COMMAND="npm run dev"; fi
fi

if [ -f "docker-compose.yml" ] || [ -f "Sail" ]; then
    DATABASE_STACK="Docker (MySQL/PostgreSQL) / Redis"
    [ -f "vendor/bin/sail" ] && TEST_COMMAND="./vendor/bin/sail test"
fi

# 2. Interactive Fallback
echo -e "  🚀 ${BLUE}Detected Stack:${NC} PHP $PHP_VERSION / $FRAMEWORK $FRAMEWORK_VERSION / $ADMIN_PANEL"
echo -ne "  ❓ Do you want to customize this stack? (y/N): "
read -r response

if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    echo -e "\n  ${YELLOW}--- Customization Menu ---${NC}"
    echo -e "  Select PHP Version:"
    options=("8.4" "8.3" "8.2" "8.1" "7.4"); select opt in "${options[@]}"; do [ -n "$opt" ] && PHP_VERSION=$opt; break; done
    echo -e "  Select Laravel Version:"
    options=("12" "11" "10" "9"); select opt in "${options[@]}"; do [ -n "$opt" ] && FRAMEWORK_VERSION=$opt; break; done
    echo -e "  Select Admin Panel:"
    options=("Filament" "Laravel Nova" "None"); select opt in "${options[@]}"; do 
        case $opt in
            "Filament") ADMIN_PANEL="Filament"; ADMIN_DIR="app/Filament"; break;;
            "Laravel Nova") ADMIN_PANEL="Laravel Nova"; ADMIN_DIR="app/Nova"; break;;
            "None") ADMIN_PANEL="None"; break;;
        esac
    done
fi

# 3. Generate Files
generate_from_template() {
    local template=$1
    local output=$2
    
    if [ -f "$template" ]; then
        # Ensure target directory exists
        mkdir -p "$(dirname "$output")"
        cp "$template" "$output"
        
        # General replacements
        sed -i '' "s/{{PROJECT_NAME}}/$PROJECT_NAME/g" "$output"
        sed -i '' "s/{{PHP_VERSION}}/$PHP_VERSION/g" "$output"
        sed -i '' "s/{{FRAMEWORK}}/$FRAMEWORK/g" "$output"
        sed -i '' "s/{{FRAMEWORK_VERSION}}/$FRAMEWORK_VERSION/g" "$output"
        sed -i '' "s/{{FRONTEND_STACK}}/$FRONTEND_STACK/g" "$output"
        sed -i '' "s/{{FRONTEND_VERSION}}/$FRONTEND_VERSION/g" "$output"
        sed -i '' "s/{{UI_LIBRARY}}/$UI_LIBRARY/g" "$output"
        sed -i '' "s/{{ADMIN_PANEL}}/$ADMIN_PANEL/g" "$output"
        sed -i '' "s/{{ADMIN_VERSION}}/v$ADMIN_VERSION/g" "$output"
        sed -i '' "s|{{ADMIN_DIR}}|$ADMIN_DIR|g" "$output"
        sed -i '' "s|{{DATABASE_STACK}}|$DATABASE_STACK|g" "$output"
        sed -i '' "s/{{ARCHITECTURE_TYPE}}/$ARCHITECTURE_TYPE/g" "$output"
        sed -i '' "s/{{BUILD_COMMAND}}/$BUILD_COMMAND/g" "$output"
        sed -i '' "s/{{DEV_COMMAND}}/$DEV_COMMAND/g" "$output"
        sed -i '' "s/{{TEST_COMMAND}}/$TEST_COMMAND/g" "$output"
        sed -i '' "s/{{TEST_WATCH_COMMAND}}/$TEST_WATCH_COMMAND/g" "$output"
        sed -i '' "s|{{PRIMARY_LANGUAGE}}|$PRIMARY_LANGUAGE|g" "$output"
        sed -i '' "s|{{FORMATTING_TOOLS}}|$FORMATTING_TOOLS|g" "$output"
        
        echo -e "  ✅ Generated: ${GREEN}$output${NC}"
    else
        echo -e "  ${RED}❌ Template not found: $template${NC}"
    fi
}

generate_from_template "$T_RULES" "$RULES_FILE"
generate_from_template "$T_GEMINI" "$GEMINI_FILE"
generate_from_template "$T_CLAUDE" "$CLAUDE_FILE"

echo -e "\n✨ Configuration complete! 🚀"
