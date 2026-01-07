# --- AI SHADOW CONTEXT ORCHESTRATION (V5) ---
# Automatically links decentralized AI context from a secure vault to local projects.

function set_gemini_context() {
    # SAFETY CHECK: Do not run if the current directory is inside the Vault itself
    if [[ "$PWD" == "$HOME/.gemini-vault"* ]]; then
        return
    fi

    local project_name=$(basename "$PWD")
    local vault_path="$HOME/.gemini-vault/$project_name"

    # Define paths for local symbolic links
    local md_context="./.opencode-context.md"
    local md_agents="./AGENTS.md"
    local json_config="./.opencode.json"

    # Cleanup existing symlinks to prevent stale references
    [[ -L "$md_context" ]] && rm "$md_context"
    [[ -L "$md_agents" ]] && rm "$md_agents"
    [[ -L "$json_config" ]] && rm "$json_config"

    # 1. Link coding guidelines
    if [[ -f "$vault_path/AGENTS.md" ]]; then
        ln -sf "$vault_path/AGENTS.md" "$md_agents"
    fi

    # 2. Link project-specific metadata
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
# Checks the integrity of the AI Shadow Vault and its project files.

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

        # Check for AGENTS.md (The Rules)
        if [[ -f "$project_path/AGENTS.md" ]]; then
            local size=$(du -sh "$project_path/AGENTS.md" | cut -f1)
            echo "  ✅ AGENTS.md (OK) ($size)"
        else
            echo "  ❌ AGENTS.md (MISSING - AI has no rules!)"
        fi

        # Check for GEMINI.md (The Context)
        if [[ -f "$project_path/GEMINI.md" ]]; then
            local size=$(du -sh "$project_path/GEMINI.md" | cut -f1)
            echo "  ✅ GEMINI.md ($size)"
        else
            echo "  ⚠️  GEMINI.md (Empty - Run /init soon)"
        fi

        # Check for opencode.json (The Models)
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
