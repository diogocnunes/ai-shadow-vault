#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
source "$SCRIPT_DIR/../lib/config.sh"
source "$SCRIPT_DIR/../lib/ui.sh"

ai_vault_require_tty "ai-vault install"

CURRENT_BASE_PATH="$(ai_vault_default_base_path)"
CURRENT_RTK_ENABLED=0
CURRENT_ADAPTERS=$'CLAUDE.md\nAGENTS.md\nGEMINI.md'

if command -v rtk >/dev/null 2>&1; then
    CURRENT_RTK_ENABLED=1
fi

if ai_vault_config_exists; then
    ai_vault_print_header "AI Shadow Vault :: Install"
    echo
    ai_vault_warning "A global config already exists at $(ai_vault_config_file)."
    if ! ai_vault_prompt_yes_no "Review and replace it?" 0; then
        ai_vault_success "Keeping existing config."
        exit 0
    fi
    ai_vault_load_config
    CURRENT_BASE_PATH="$AI_VAULT_CONFIG_BASE_PATH"
    CURRENT_RTK_ENABLED="$AI_VAULT_CONFIG_RTK_INSTRUCTIONS"
    CURRENT_ADAPTERS="$AI_VAULT_CONFIG_ADAPTERS"
fi

BASE_PATH_CHOICES=()
while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    BASE_PATH_CHOICES+=("$line")
done < <(ai_vault_detect_base_path_candidates)
if ! printf '%s\n' "${BASE_PATH_CHOICES[@]}" | grep -Fxq "$CURRENT_BASE_PATH"; then
    BASE_PATH_CHOICES+=("$CURRENT_BASE_PATH")
fi

ai_vault_print_header "AI Shadow Vault :: Install"
echo
printf '%s\n' "$(ai_vault_muted 'Keep adapter files out of Git and link them into each project.')"
echo
ai_vault_print_install_panel
echo
ai_vault_action "Choose where project vaults should live."
echo

CHOICE_WIDTH="$(ai_vault_terminal_width)"
if (( CHOICE_WIDTH > 16 )); then
    CHOICE_WIDTH=$((CHOICE_WIDTH - 8))
else
    CHOICE_WIDTH=40
fi

for i in "${!BASE_PATH_CHOICES[@]}"; do
    display_path="$(ai_vault_truncate_text "${BASE_PATH_CHOICES[$i]}" "$CHOICE_WIDTH")"
    printf '  %d. %s\n' "$((i + 1))" "$display_path"
done
printf '  %d. Custom path\n' "$(( ${#BASE_PATH_CHOICES[@]} + 1 ))"
echo

DEFAULT_SELECTION=1
for i in "${!BASE_PATH_CHOICES[@]}"; do
    if [[ "${BASE_PATH_CHOICES[$i]}" == "$CURRENT_BASE_PATH" ]]; then
        DEFAULT_SELECTION="$((i + 1))"
        break
    fi
done
VAULT_BASE_PATH=""
while [[ -z "$VAULT_BASE_PATH" ]]; do
    selection="$(ai_vault_prompt_text "Base path choice" "$DEFAULT_SELECTION")"
    if [[ "$selection" =~ ^[0-9]+$ ]]; then
        if (( selection >= 1 && selection <= ${#BASE_PATH_CHOICES[@]} )); then
            VAULT_BASE_PATH="${BASE_PATH_CHOICES[$((selection - 1))]}"
            break
        fi
        if (( selection == ${#BASE_PATH_CHOICES[@]} + 1 )); then
            VAULT_BASE_PATH="$(ai_vault_prompt_text "Enter custom base path" "$(ai_vault_default_base_path)")"
            break
        fi
    fi
    ai_vault_warning "Enter a valid option number."
done

ADAPTERS=()
echo
ai_vault_action "Configure default adapters."
for adapter in CLAUDE.md AGENTS.md GEMINI.md; do
    default_enabled=0
    if grep -Fxq "$adapter" <<<"$CURRENT_ADAPTERS"; then
        default_enabled=1
    fi
    if ai_vault_prompt_yes_no "Enable $adapter?" "$default_enabled"; then
        ADAPTERS+=("$adapter")
    fi
done

if [[ "${#ADAPTERS[@]}" -eq 0 ]]; then
    ai_vault_error "At least one adapter must be enabled."
    exit 1
fi

echo
RTK_AVAILABLE=0
command -v rtk >/dev/null 2>&1 && RTK_AVAILABLE=1
RTK_ENABLED=0
if [[ "$RTK_AVAILABLE" -eq 1 ]]; then
    if ai_vault_prompt_yes_no "Include RTK instructions when RTK is available?" "$CURRENT_RTK_ENABLED"; then
        RTK_ENABLED=1
    fi
else
    ai_vault_warning "RTK not detected. RTK instructions will stay disabled."
fi

echo
ai_vault_action "Review setup choices."
echo "  Base path: $VAULT_BASE_PATH"
echo "  Adapters: ${ADAPTERS[*]}"
if [[ "$RTK_ENABLED" -eq 1 ]]; then
    echo "  RTK instructions: enabled"
else
    echo "  RTK instructions: disabled"
fi

if ! ai_vault_prompt_yes_no "Write global config?" 1; then
    ai_vault_error "Aborted."
    exit 1
fi

adapters_csv="$(IFS=,; echo "${ADAPTERS[*]}")"
ai_vault_write_config "$VAULT_BASE_PATH" "$adapters_csv" "$RTK_ENABLED"

echo
ai_vault_success "Setup complete"
echo
echo "Next step:"
echo
echo "  cd your-project"
echo "  ai-vault init"
