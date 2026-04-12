#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
source "$SCRIPT_DIR/../lib/config.sh"

case "$(ai_vault_install_mode)" in
    homebrew)
        ai_vault_action "AI Shadow Vault is managed by Homebrew."
        ai_vault_success "Use: brew upgrade ai-vault"
        ;;
    git)
        INSTALL_ROOT="$(ai_vault_repo_root)"
        cd "$INSTALL_ROOT"
        git fetch origin main -q

        LOCAL_HEAD="$(git rev-parse HEAD)"
        REMOTE_HEAD="$(git rev-parse origin/main)"

        if [[ "$LOCAL_HEAD" == "$REMOTE_HEAD" ]]; then
            ai_vault_success "Already up to date."
            exit 0
        fi

        git checkout main -q
        git pull --ff-only origin main -q

        ai_vault_success "Update complete."
        ;;
    *)
        ai_vault_warning "This install is not self-updatable."
        ai_vault_action "Reinstall the latest release package or use Homebrew."
        ;;
esac
