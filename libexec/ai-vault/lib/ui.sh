#!/bin/bash

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

ai_vault_colors_enabled() {
    [[ -t 1 ]] || return 1
    [[ -z "${NO_COLOR:-}" ]] || return 1
    [[ "${TERM:-}" != "dumb" ]] || return 1
}

ai_vault_color() {
    local code="$1"
    local text="$2"

    if ai_vault_colors_enabled; then
        printf '\033[%sm%s\033[0m' "$code" "$text"
        return
    fi

    printf '%s' "$text"
}

ai_vault_accent() {
    ai_vault_color "96" "$1"
}

ai_vault_muted() {
    ai_vault_color "90" "$1"
}

ai_vault_title() {
    ai_vault_color "96;1" "$1"
}

ai_vault_shadow() {
    ai_vault_color "94;1" "$1"
}

ai_vault_terminal_width() {
    if [[ -n "${COLUMNS:-}" && "${COLUMNS:-0}" -gt 0 ]]; then
        printf '%s\n' "$COLUMNS"
        return
    fi

    if command -v tput >/dev/null 2>&1; then
        tput cols 2>/dev/null && return
    fi

    printf '%s\n' "80"
}

ai_vault_print_header() {
    local subtitle="${1:-Keep context out of Git}"
    local width
    local compact_title
    local line_1 line_2 line_3 line_4 line_5 line_6 badge

    width="$(ai_vault_terminal_width)"

    if [[ "$width" -lt 32 ]]; then
        compact_title="$subtitle"
        if [[ "$compact_title" != AI\ Shadow\ Vault\ ::* ]]; then
            compact_title="AI Shadow Vault :: $compact_title"
        fi
        printf '%s\n' "$(ai_vault_title "$compact_title")"
        return
    fi

    if [[ "$width" -lt 72 ]]; then
        printf '%s\n' "$(ai_vault_title ' █████╗ ██╗   Shadow Vault')"
        printf '%s\n' "$(ai_vault_title '██╔══██╗██║')"
        printf '%s\n' "$(ai_vault_title '███████║██║')"
        printf '%s\n' "$(ai_vault_title '██╔══██║██║')"
        printf '%s\n' "$(ai_vault_title '██║  ██║██║')"
        printf '%s\n' "$(ai_vault_title '╚═╝  ╚═╝╚═╝')"
        printf '%s\n' "$(ai_vault_accent "$subtitle")"
        return
    fi

    line_1="$(ai_vault_title ' █████╗ ██╗    ')$(ai_vault_shadow '███████╗██╗  ██╗ █████╗ ██████╗  ██████╗ ██╗    ██╗')"
    line_2="$(ai_vault_title '██╔══██╗██║    ')$(ai_vault_shadow '██╔════╝██║  ██║██╔══██╗██╔══██╗██╔═══██╗██║    ██║')"
    line_3="$(ai_vault_title '███████║██║    ')$(ai_vault_shadow '███████╗███████║███████║██║  ██║██║   ██║██║ █╗ ██║')"
    line_4="$(ai_vault_title '██╔══██║██║    ')$(ai_vault_shadow '╚════██║██╔══██║██╔══██║██║  ██║██║   ██║██║███╗██║')"
    line_5="$(ai_vault_title '██║  ██║██║    ')$(ai_vault_shadow '███████║██║  ██║██║  ██║██████╔╝╚██████╔╝╚███╔███╔╝')"
    line_6="$(ai_vault_title '╚═╝  ╚═╝╚═╝    ')$(ai_vault_shadow '╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═════╝  ╚═════╝  ╚══╝╚══╝ ')"
    badge="$(ai_vault_accent "✦ $subtitle ✦")"

    printf '%s\n%s\n%s\n%s\n%s\n%s\n%s\n' \
        "$line_1" \
        "$line_2" \
        "$line_3" \
        "$line_4" \
        "$line_5" \
        "$line_6" \
        "$badge"
}

ai_vault_print_install_panel() {
    local width
    width="$(ai_vault_terminal_width)"

    if [[ "$width" -lt 72 ]]; then
        printf '%s\n' "$(ai_vault_muted 'This setup will configure:')"
        printf '  %s Vault storage path\n' "$(ai_vault_accent '•')"
        printf '  %s Default adapters\n' "$(ai_vault_accent '•')"
        printf '  %s Optional RTK instructions\n' "$(ai_vault_accent '•')"
        printf '  %s Optional Caveman instructions\n' "$(ai_vault_accent '•')"
        printf '  %s Optional Superpowers instructions\n' "$(ai_vault_accent '•')"
        printf '  %s Optional Context Mode instructions\n' "$(ai_vault_accent '•')"
        printf '  %s Optional Superpowers docs usage\n' "$(ai_vault_accent '•')"
        return
    fi

    printf '%s\n' "$(ai_vault_accent '┌──────────────────────────────────────────────────────────────┐')"
    printf '%s\n' "$(ai_vault_title  '│ What should AI Shadow Vault configure?                      │')"
    printf '%s\n' "$(ai_vault_accent '│ › Vault storage path                                        │')"
    printf '%s\n' "$(ai_vault_accent '│ › Default adapters                                          │')"
    printf '%s\n' "$(ai_vault_accent '│ › Optional RTK instructions                                 │')"
    printf '%s\n' "$(ai_vault_accent '│ › Optional Caveman instructions                             │')"
    printf '%s\n' "$(ai_vault_accent '│ › Optional Superpowers instructions                         │')"
    printf '%s\n' "$(ai_vault_accent '│ › Optional Context Mode instructions                        │')"
    printf '%s\n' "$(ai_vault_accent '│ › Optional Superpowers docs usage                           │')"
    printf '%s\n' "$(ai_vault_accent '└──────────────────────────────────────────────────────────────┘')"
}

ai_vault_truncate_text() {
    local text="$1"
    local max_width="$2"
    local text_length

    text_length="${#text}"
    if (( text_length <= max_width )); then
        printf '%s\n' "$text"
        return
    fi

    if (( max_width <= 3 )); then
        printf '%s\n' "${text:0:max_width}"
        return
    fi

    printf '%s...\n' "${text:0:max_width-3}"
}

ai_vault_prompt_yes_no() {
    local prompt="$1"
    local default_value="$2"
    local answer=""

    if [[ "$default_value" == "1" ]]; then
        printf '%s [Y/n]: ' "$prompt" >&2
        read -r answer
        answer="${answer//$'\r'/}"
        [[ -z "$answer" || "$answer" =~ ^([yY]|[yY][eE][sS])$ ]]
        return
    fi

    printf '%s [y/N]: ' "$prompt" >&2
    read -r answer
    answer="${answer//$'\r'/}"
    [[ "$answer" =~ ^([yY]|[yY][eE][sS])$ ]]
}

ai_vault_prompt_text() {
    local prompt="$1"
    local default_value="${2:-}"
    local answer=""

    if [[ -n "$default_value" ]]; then
        printf '%s [%s]: ' "$prompt" "$default_value" >&2
    else
        printf '%s: ' "$prompt" >&2
    fi
    read -r answer
    answer="${answer//$'\r'/}"

    if [[ -z "$answer" ]]; then
        printf '%s\n' "$default_value"
        return
    fi

    printf '%s\n' "$answer"
}
