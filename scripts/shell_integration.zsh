# --- AI SHADOW CONTEXT ORCHESTRATION (V6.1) ---

function set_gemini_context() {
    # SAFETY CHECK: Do not run if the current directory is inside the Vault itself
    if [[ "$PWD" == "$HOME/.gemini-vault"* ]]; then
        return
    fi

    local project_name=$(basename "$PWD")
    local vault_path="$HOME/.gemini-vault/$project_name"

    # Define paths - Standardized to GEMINI.md for gemini-cli compatibility
    local md_context="./GEMINI.md"
    local md_context_legacy="./.opencode-context.md"
    local md_agents="./AGENTS.md"
    local json_config="./.opencode.json"

    # Laravel Boost files
    local mcp_config="./.mcp.json"
    local claude_md="./CLAUDE.md"
    local boost_config="./boost.json"

    # Cleanup existing symlinks (including legacy names)
    [[ -L "$md_context" ]] && rm "$md_context"
    [[ -L "$md_context_legacy" ]] && rm "$md_context_legacy"
    [[ -L "$md_agents" ]] && rm "$md_agents"
    [[ -L "$json_config" ]] && rm "$json_config"

    # Cleanup Laravel Boost files (real files, not symlinks)
    # These are auto-generated and should not exist in the working directory
    # as Shadow Vault takes precedence for context injection
    [[ -f "$mcp_config" ]] && rm "$mcp_config"
    [[ -f "$claude_md" ]] && rm "$claude_md"
    [[ -f "$boost_config" ]] && rm "$boost_config"

    # AGENTS.md can be created by Laravel Boost as a real file
    # Remove it if it exists as a real file (not a symlink) to avoid conflicts
    [[ -f "$md_agents" && ! -L "$md_agents" ]] && rm "$md_agents"

    # 1. Link coding guidelines
    if [[ -f "$vault_path/AGENTS.md" ]]; then
        ln -sf "$vault_path/AGENTS.md" "$md_agents"
    fi

    # 2. Link project-specific metadata (Unified Name)
    if [[ -f "$vault_path/GEMINI.md" ]]; then
        ln -sf "$vault_path/GEMINI.md" "$md_context"
    fi

    # 3. Link agent configuration (Project-specific OR Global stack)
    local common_config="$HOME/.gemini-vault/laravel_nova_stack.json"
    if [[ -f "$vault_path/opencode.json" ]]; then
        ln -sf "$vault_path/opencode.json" "$json_config"
    elif [[ -f "$common_config" ]]; then
        ln -sf "$common_config" "$json_config"
    fi
}

autoload -U add-zsh-hook
add-zsh-hook chpwd set_gemini_context
set_gemini_context

# --- VAULT HEALTH MONITOR ---

function vault-check() {
    local vault_root="$HOME/.gemini-vault"
    echo "\n🔍 Starting AI Shadow Vault Health Check..."
    echo "------------------------------------------"

    if [[ ! -d "$vault_root" ]]; then
        echo "❌ Error: Vault root not found at $vault_root"
        return 1
    fi

    # Iterate through each project directory in the Vault
    for project_path in "$vault_root"/*(/); do
        local project_name=$(basename "$project_path")
        echo "📁 Project: \033[1;34m$project_name\033[0m"

        # Check for AGENTS.md
        if [[ -f "$project_path/AGENTS.md" ]]; then
            local size=$(du -sh "$project_path/AGENTS.md" | cut -f1)
            echo "  ✅ AGENTS.md (OK) ($size)"
        else
            echo "  ❌ AGENTS.md (MISSING - AI has no rules!)"
        fi

        # Check for GEMINI.md
        if [[ -f "$project_path/GEMINI.md" ]]; then
            local size=$(du -sh "$project_path/GEMINI.md" | cut -f1)
            echo "  ✅ GEMINI.md ($size)"
        else
            echo "  ⚠️  GEMINI.md (Empty - Run vault-init soon)"
        fi

        # Check for opencode.json
        if [[ -f "$project_path/opencode.json" ]]; then
            echo "  ✅ opencode.json (Custom Config)"
        else
            echo "  ℹ️  opencode.json (Using Global Config)"
        fi
        echo ""
    done

    echo "------------------------------------------"
    echo "✨ Vault Scan Complete."
}

# --- ALIASES ---
alias vault-init="~/.ai-shadow-vault/bin/vault-init.sh"
alias vault-update="~/.ai-shadow-vault/bin/vault-update.sh"
