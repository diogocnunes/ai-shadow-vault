# --- AI SHADOW CONTEXT ORCHESTRATION (V6) ---
function set_gemini_context() {
    if [[ "$PWD" == "$HOME/.gemini-vault"* ]]; then return; fi

    local project_name=$(basename "$PWD")
    local vault_path="$HOME/.gemini-vault/$project_name"

    # Define paths - Standardized to GEMINI.md for gemini-cli compatibility
    local md_context="./GEMINI.md"
    local md_context_legacy="./.opencode-context.md"
    local md_agents="./AGENTS.md"
    local json_config="./.opencode.json"

    # Cleanup existing symlinks (including legacy names)
    [[ -L "$md_context" ]] && rm "$md_context"
    [[ -L "$md_context_legacy" ]] && rm "$md_context_legacy"
    [[ -L "$md_agents" ]] && rm "$md_agents"
    [[ -L "$json_config" ]] && rm "$json_config"

    # 1. Link coding guidelines
    [[ -f "$vault_path/AGENTS.md" ]] && ln -sf "$vault_path/AGENTS.md" "$md_agents"

    # 2. Link project-specific metadata (Unified Name)
    [[ -f "$vault_path/GEMINI.md" ]] && ln -sf "$vault_path/GEMINI.md" "$md_context"

    # 3. Link agent configuration
    local common_config="$HOME/.gemini-vault/laravel_nova_stack.json"
    if [[ -f "$vault_path/opencode.json" ]]; then
        ln -sf "$vault_path/opencode.json" "$json_config"
    elif [[ -f "$common_config" ]]; then
        ln -sf "$common_config" "$json_config"
    fi
}

# --- ALIASES ---
alias vault-init="~/.ai-shadow-vault/bin/vault-init.sh"