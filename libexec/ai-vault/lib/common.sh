#!/bin/bash

AI_VAULT_SUCCESS_SYMBOL="✔"
AI_VAULT_ACTION_SYMBOL="→"
AI_VAULT_WARNING_SYMBOL="⚠"
AI_VAULT_ERROR_SYMBOL="✖"

ai_vault_home() {
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    printf '%s\n' "$(cd "$script_dir/.." && pwd)"
}

ai_vault_repo_root() {
    printf '%s\n' "$(cd "$(ai_vault_home)/../.." && pwd)"
}

ai_vault_python() {
    if command -v python3 >/dev/null 2>&1; then
        command -v python3
        return 0
    fi

    echo "python3 is required for AI Shadow Vault." >&2
    return 1
}

ai_vault_is_git_install() {
    git -C "$(ai_vault_repo_root)" rev-parse --show-toplevel >/dev/null 2>&1
}

ai_vault_require_tty() {
    local action="$1"

    if [[ ! -t 0 || ! -t 1 ]]; then
        ai_vault_error "$action requires an interactive terminal." >&2
        return 1
    fi
}

ai_vault_action() {
    printf '%s %s\n' "$AI_VAULT_ACTION_SYMBOL" "$*"
}

ai_vault_success() {
    printf '%s %s\n' "$AI_VAULT_SUCCESS_SYMBOL" "$*"
}

ai_vault_warning() {
    printf '%s %s\n' "$AI_VAULT_WARNING_SYMBOL" "$*"
}

ai_vault_error() {
    printf '%s %s\n' "$AI_VAULT_ERROR_SYMBOL" "$*" >&2
}
