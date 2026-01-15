# --- AI SHADOW CONTEXT ORCHESTRATION (V7.0) ---

function set_gemini_context() {
    if [[ "$PWD" == "$HOME/.gemini-vault"* ]]; then
        return
    fi

    local project_name=$(basename "$PWD")
    local vault_path="$HOME/.gemini-vault/$project_name"

    # Define paths
    local md_context="./GEMINI.md"
    local md_agents="./AGENTS.md"
    local json_config="./.opencode.json"
    local copilot_dest="./.github/copilot-instructions.md"

    # Laravel Boost files
    local mcp_config="./.mcp.json"
    local claude_md="./CLAUDE.md"
    local boost_config="./boost.json"

    # Cleanup existing symlinks (including legacy names)
    [[ -L "$md_context" ]] && rm "$md_context"
    [[ -L "$md_agents" ]] && rm "$md_agents"
    [[ -L "$json_config" ]] && rm "$json_config"
    [[ -L "$copilot_dest" ]] && rm "$copilot_dest"

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

    # 3. Link Copilot Instructions (Special Case: needs .github folder)
    if [[ -f "$vault_path/copilot-instructions.md" ]]; then
        mkdir -p "./.github"
        ln -sf "$vault_path/copilot-instructions.md" "$copilot_dest"
    fi

    # 4. Link JSON Config
    local common_config="$HOME/.gemini-vault/laravel_nova_stack.json"
    if [[ -f "$vault_path/opencode.json" ]]; then
        ln -sf "$vault_path/opencode.json" "$json_config"
    elif [[ -f "$common_config" ]]; then
        ln -sf "$common_config" "$json_config"
    fi
}

# --- VAULT HEALTH MONITOR (Updated) ---

function vault-check() {
    local vault_root="$HOME/.gemini-vault"
    echo "\n🔍 Starting AI Shadow Vault Health Check..."
    echo "------------------------------------------"

    for project_path in "$vault_root"/*(/); do
        local project_name=$(basename "$project_path")
        echo "📁 Project: \033[1;34m$project_name\033[0m"

        # Check AGENTS
        [[ -f "$project_path/AGENTS.md" ]] && echo "  ✅ AGENTS.md" || echo "  ❌ AGENTS.md (MISSING)"

        # Check GEMINI
        [[ -f "$project_path/GEMINI.md" ]] && echo "  ✅ GEMINI.md" || echo "  ⚠️  GEMINI.md (Empty)"

        # Check COPILOT
        [[ -f "$project_path/copilot-instructions.md" ]] && echo "  ✅ Copilot Instructions" || echo "  ℹ️  Copilot (Not Configured)"

        echo ""
    done
    echo "------------------------------------------"
}