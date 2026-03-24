#!/bin/bash

# AI Shadow Vault - Project Configurator
# Generates canonical rules and project-context files.

set -euo pipefail

NON_INTERACTIVE=0
RULES_ONLY=0
FORCE_HERD=0

while [[ "$#" -gt 0 ]]; do
    case "${1:-}" in
        --non-interactive)
            NON_INTERACTIVE=1
            ;;
        --rules-only)
            RULES_ONLY=1
            ;;
        --herd)
            FORCE_HERD=1
            NON_INTERACTIVE=1
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
    shift
done

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

TEMPLATES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../templates" && pwd)"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/vault-resolver.sh"

PROJECT_ROOT="$(vault_resolve_project_root "$PWD")"
PROJECT_NAME="$(vault_resolve_project_slug "$PROJECT_ROOT")"

cd "$PROJECT_ROOT"

AI_DIR=".ai"
RULES_FILE="$AI_DIR/rules.md"
PROJECT_CONTEXT_FILE="$AI_DIR/context/project-context.md"

T_RULES="$TEMPLATES_DIR/.ai/rules.md"
T_PROJECT_CONTEXT="$TEMPLATES_DIR/.ai/context/project-context.md"

PHP_VERSION="8.3"
FRAMEWORK="Unknown"
FRAMEWORK_VERSION="N/A"
FRONTEND_STACK="Unknown"
FRONTEND_VERSION="N/A"
UI_LIBRARY="None"
DATABASE_STACK="Unknown"
DEV_ENVIRONMENT="Unknown"
PROJECT_CONTEXT="[Provide a brief description of the business goal here]"
KEY_INTEGRATIONS="[List integrations like Stripe, AWS, etc.]"
ARCHITECTURE_TYPE="Monolithic"
BUILD_COMMAND="npm run build"
DEV_COMMAND="npm run dev"
TEST_COMMAND="npm test"

extract_existing_value() {
    local key="$1"
    local file="$2"
    [[ -f "$file" ]] || return 1

    grep -E "^- ${key}:" "$file" | head -n 1 | sed -E "s/^- ${key}:[[:space:]]*//" || true
}

if [[ -f "$PROJECT_CONTEXT_FILE" ]]; then
    existing_purpose="$(extract_existing_value "Primary purpose" "$PROJECT_CONTEXT_FILE" || true)"
    existing_integrations="$(extract_existing_value "Key integrations" "$PROJECT_CONTEXT_FILE" || true)"
    [[ -n "$existing_purpose" ]] && PROJECT_CONTEXT="$existing_purpose"
    [[ -n "$existing_integrations" ]] && KEY_INTEGRATIONS="$existing_integrations"
fi

if [[ -f "composer.json" ]]; then
    FRAMEWORK="PHP"
    TEST_COMMAND="php artisan test"

    detected_php="$(grep '"php":' composer.json | head -n 1 | grep -o '[0-9]\.[0-9]' | head -n 1 || true)"
    [[ -n "$detected_php" ]] && PHP_VERSION="$detected_php"

    if grep -q '"laravel/framework"' composer.json; then
        FRAMEWORK="Laravel"
        detected_laravel="$(grep '"laravel/framework":' composer.json | grep -o '[0-9]\+' | head -n 1 || true)"
        [[ -n "$detected_laravel" ]] && FRAMEWORK_VERSION="$detected_laravel"
        DEV_ENVIRONMENT="Laravel Herd"
    fi

    if grep -q '"pestphp/pest"' composer.json; then
        TEST_COMMAND="./vendor/bin/pest"
    fi
fi

if [[ -f "package.json" ]]; then
    if grep -q '"vue":' package.json; then
        FRONTEND_STACK="Vue.js"
        FRONTEND_VERSION="$(grep '"vue":' package.json | grep -o '[0-9]\+' | head -n 1 || true)"
        [[ -z "$FRONTEND_VERSION" ]] && FRONTEND_VERSION="3"
    else
        FRONTEND_STACK="JavaScript"
        FRONTEND_VERSION="N/A"
    fi

    if grep -q 'primevue' package.json; then
        UI_LIBRARY="PrimeVue"
    elif grep -q 'quasar' package.json; then
        UI_LIBRARY="Quasar"
    elif grep -q 'tailwindcss' package.json; then
        UI_LIBRARY="TailwindCSS"
    fi
fi

if [[ -f "docker-compose.yml" || -f "docker-compose.yaml" ]]; then
    DEV_ENVIRONMENT="Docker"
fi

if [[ "$FORCE_HERD" -eq 1 ]]; then
    DEV_ENVIRONMENT="Laravel Herd"
fi

[[ "$DATABASE_STACK" == "Unknown" ]] && DATABASE_STACK="MySQL"
[[ "$FRAMEWORK_VERSION" == "N/A" ]] && FRAMEWORK_VERSION="N/A"
[[ "$DEV_ENVIRONMENT" == "Unknown" ]] && DEV_ENVIRONMENT="Local"

if [[ "$NON_INTERACTIVE" -eq 0 ]]; then
    echo -e "${BLUE}⚙️  Configure AI Shadow Vault project context${NC}"
    echo -e "Detected: ${YELLOW}$FRAMEWORK $FRAMEWORK_VERSION / PHP $PHP_VERSION / $FRONTEND_STACK${NC}"
    echo

    read -r -p "Business goal [$PROJECT_CONTEXT]: " input_goal
    [[ -n "$input_goal" ]] && PROJECT_CONTEXT="$input_goal"

    read -r -p "Key integrations [$KEY_INTEGRATIONS]: " input_integrations
    [[ -n "$input_integrations" ]] && KEY_INTEGRATIONS="$input_integrations"

    read -r -p "Architecture type [$ARCHITECTURE_TYPE]: " input_arch
    [[ -n "$input_arch" ]] && ARCHITECTURE_TYPE="$input_arch"
fi

generate_from_template() {
    local template="$1"
    local output="$2"

    [[ -f "$template" ]] || return 0

    mkdir -p "$(dirname "$output")"
    cp "$template" "$output"

    sed -i '' "s|{{PROJECT_NAME}}|$PROJECT_NAME|g" "$output"
    sed -i '' "s|{{PHP_VERSION}}|$PHP_VERSION|g" "$output"
    sed -i '' "s|{{FRAMEWORK}}|$FRAMEWORK|g" "$output"
    sed -i '' "s|{{FRAMEWORK_VERSION}}|$FRAMEWORK_VERSION|g" "$output"
    sed -i '' "s|{{FRONTEND_STACK}}|$FRONTEND_STACK|g" "$output"
    sed -i '' "s|{{FRONTEND_VERSION}}|$FRONTEND_VERSION|g" "$output"
    sed -i '' "s|{{UI_LIBRARY}}|$UI_LIBRARY|g" "$output"
    sed -i '' "s|{{DATABASE_STACK}}|$DATABASE_STACK|g" "$output"
    sed -i '' "s|{{DEV_ENVIRONMENT}}|$DEV_ENVIRONMENT|g" "$output"
    sed -i '' "s|{{PROJECT_CONTEXT}}|$PROJECT_CONTEXT|g" "$output"
    sed -i '' "s|{{KEY_INTEGRATIONS}}|$KEY_INTEGRATIONS|g" "$output"
    sed -i '' "s|{{ARCHITECTURE_TYPE}}|$ARCHITECTURE_TYPE|g" "$output"
    sed -i '' "s|{{BUILD_COMMAND}}|$BUILD_COMMAND|g" "$output"
    sed -i '' "s|{{DEV_COMMAND}}|$DEV_COMMAND|g" "$output"
    sed -i '' "s|{{TEST_COMMAND}}|$TEST_COMMAND|g" "$output"

    echo -e "  ✅ Generated: ${GREEN}$output${NC}"
}

echo -e "${BLUE}🧱 Generating canonical vault context...${NC}"

generate_from_template "$T_RULES" "$RULES_FILE"

if [[ "$RULES_ONLY" -eq 0 ]]; then
    generate_from_template "$T_PROJECT_CONTEXT" "$PROJECT_CONTEXT_FILE"
fi

echo -e "\n✨ Configuration complete."
