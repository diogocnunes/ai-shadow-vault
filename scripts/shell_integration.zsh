# --- AI SHADOW CONTEXT ORCHESTRATION (V7.0) ---

if [[ -n "${AI_SHADOW_SHELL_INTEGRATION_LOADED:-}" ]]; then
    autoload -U add-zsh-hook
    add-zsh-hook -D chpwd set_gemini_context 2>/dev/null || true
    add-zsh-hook -D chpwd check_ai_cache 2>/dev/null || true
fi
export AI_SHADOW_SHELL_INTEGRATION_LOADED=1

AI_SHADOW_SHELL_DIR="${${(%):-%N}:A:h}"
source "$AI_SHADOW_SHELL_DIR/lib/vault-resolver.sh"

function set_gemini_context() {
    if vault_is_inside_data_root "$PWD"; then
        return
    fi

    local project_root="$(vault_resolve_project_root "$PWD")"
    local vault_path="$(vault_resolve_existing_project_vault "$project_root")"

    # Define paths (relative to project root)
    local md_context="$project_root/GEMINI.md"
    local md_agents="$project_root/AGENTS.md"
    local json_config="$project_root/.opencode.json"
    local copilot_dest="$project_root/.github/copilot-instructions.md"
    local claude_md="$project_root/CLAUDE.md"
    local cursor_rules="$project_root/.cursorrules"
    local windsurf_rules="$project_root/.windsurfrules"
    local cody_context="$project_root/.cody/context.json"
    local cody_ignore="$project_root/.cody/ignore"

    # Laravel Boost files
    local mcp_config="$project_root/.mcp.json"
    local boost_config="$project_root/boost.json"

    # Cleanup existing symlinks (Universal AI)
    [[ -L "$md_context" ]] && rm "$md_context"
    [[ -L "$md_agents" ]] && rm "$md_agents"
    [[ -L "$json_config" ]] && rm "$json_config"
    [[ -L "$copilot_dest" ]] && rm "$copilot_dest"
    [[ -L "$claude_md" ]] && rm "$claude_md"
    [[ -L "$cursor_rules" ]] && rm "$cursor_rules"
    [[ -L "$windsurf_rules" ]] && rm "$windsurf_rules"
    [[ -L "$cody_context" ]] && rm "$cody_context"
    [[ -L "$cody_ignore" ]] && rm "$cody_ignore"

    # Cleanup Laravel Boost files (real files, not symlinks)
    [[ -f "$mcp_config" ]] && rm "$mcp_config"
    [[ -f "$claude_md" && ! -L "$claude_md" ]] && rm "$claude_md"
    [[ -f "$boost_config" ]] && rm "$boost_config"

    # AGENTS.md can be created by Laravel Boost as a real file
    [[ -f "$md_agents" && ! -L "$md_agents" ]] && rm "$md_agents"

    # 1. Link coding guidelines
    [[ -f "$vault_path/AGENTS.md" ]] && ln -sf "$vault_path/AGENTS.md" "$md_agents"
    [[ -f "$vault_path/GEMINI.md" ]] && ln -sf "$vault_path/GEMINI.md" "$md_context"
    [[ -f "$vault_path/CLAUDE.md" ]] && ln -sf "$vault_path/CLAUDE.md" "$claude_md"

    # 2. Link Editor Rules
    [[ -f "$vault_path/.cursorrules" ]] && ln -sf "$vault_path/.cursorrules" "$cursor_rules"
    [[ -f "$vault_path/.windsurfrules" ]] && ln -sf "$vault_path/.windsurfrules" "$windsurf_rules"

    # 3. Link Copilot (Special Case: needs .github folder)
    if [[ -f "$vault_path/copilot-instructions.md" ]]; then
        mkdir -p "$project_root/.github"
        ln -sf "$vault_path/copilot-instructions.md" "$copilot_dest"
    fi

    # 4. Link Cody/Junie (Special Case: needs .cody folder)
    if [[ -f "$vault_path/cody-context.json" || -f "$vault_path/cody-ignore" ]]; then
        mkdir -p "$project_root/.cody"
        [[ -f "$vault_path/cody-context.json" ]] && ln -sf "$vault_path/cody-context.json" "$cody_context"
        [[ -f "$vault_path/cody-ignore" ]] && ln -sf "$vault_path/cody-ignore" "$cody_ignore"
    fi

    # 5. Link JSON Config
    local common_config="$(vault_shared_asset_path "laravel_nova_stack.json")"
    if [[ -f "$vault_path/opencode.json" ]]; then
        ln -sf "$vault_path/opencode.json" "$json_config"
    elif [[ -f "$common_config" ]]; then
        ln -sf "$common_config" "$json_config"
    fi
}

# --- VAULT HEALTH MONITOR (Updated) ---

function check_vault_project() {
    local project_path="$1"
    local project_name="$(basename "$project_path")"
    echo "📁 Project: \033[1;34m$project_name\033[0m"

    check_vault_file "$project_path/AGENTS.md" "AGENTS.md"
    check_vault_file "$project_path/GEMINI.md" "GEMINI.md"
    check_vault_file "$project_path/CLAUDE.md" "CLAUDE.md"
    check_vault_file "$project_path/.cursorrules" ".cursorrules"
    check_vault_file "$project_path/.windsurfrules" ".windsurfrules"
    check_vault_file "$project_path/copilot-instructions.md" "Copilot Instructions"
    check_vault_file "$project_path/cody-context.json" "Cody Context"
    check_vault_file "$project_path/cody-ignore" "Cody Ignore"

    echo ""
}

function vault-check() {
    local primary_root="$(vault_primary_data_root)"
    local legacy_root="$(vault_legacy_data_root)"
    echo "\n🔍 Starting AI Shadow Vault Health Check..."
    echo "------------------------------------------"

    local project_path
    if [[ -d "$primary_root" ]]; then
        for project_path in "$primary_root"/*(/N); do
            [[ "$(basename "$project_path")" == "by-repo" || "$(basename "$project_path")" == "templates" ]] && continue
            check_vault_project "$project_path"
        done
    fi

    if [[ -d "$primary_root/by-repo" ]]; then
        for project_path in "$primary_root"/by-repo/**/*(/N); do
            [[ -f "$project_path/AGENTS.md" || -f "$project_path/GEMINI.md" || -f "$project_path/CLAUDE.md" ]] || continue
            check_vault_project "$project_path"
        done
    fi

    if [[ -d "$legacy_root" ]]; then
        for project_path in "$legacy_root"/*(/N); do
            [[ "$(basename "$project_path")" == "by-repo" || "$(basename "$project_path")" == "templates" ]] && continue
            check_vault_project "$project_path"
        done
    fi

    if [[ -d "$legacy_root/by-repo" ]]; then
        for project_path in "$legacy_root"/by-repo/**/*(/N); do
            [[ -f "$project_path/AGENTS.md" || -f "$project_path/GEMINI.md" || -f "$project_path/CLAUDE.md" ]] || continue
            check_vault_project "$project_path"
        done
    fi

    echo "------------------------------------------"
}

function check_vault_file() {
    local file_path=$1
    local label=$2
    if [[ -f "$file_path" ]]; then
        local size=$(du -h "$file_path" | cut -f1)
        echo "  ✅ $label ($size)"
    else
        echo "  ❌ $label (MISSING)"
    fi
}

# --- AI Cache System Integration ---

function claude-start() {
    local project_root="$(vault_resolve_project_root "$PWD")"

    if [[ "$project_root" == "/" || ! -d "$project_root/.ai" ]]; then
        echo "\033[1;33m⚠️  No .ai directory found in project tree. Run vault-init first.\033[0m"
        return
    fi

    local context_file="$project_root/.ai/context/agent-context.md"
    if [[ -x "$AI_SHADOW_SHELL_DIR/vault-ai-context-file.sh" ]]; then
        (cd "$project_root" && "$AI_SHADOW_SHELL_DIR/vault-ai-context-file.sh" >/dev/null)
    fi

    # Go to root for vault-ai-resume to ensure it finds .ai
    (cd "$project_root" && echo "\033[0;34m🛡️  AI Shadow Vault - Claude Context Recap\033[0m" && echo "------------------------------------------" && vault-ai-resume)

    if [[ -f "$project_root/.ai/rules.md" ]]; then
        if command -v pbcopy >/dev/null 2>&1; then
            cat "$project_root/.ai/rules.md" | pbcopy
            echo "\033[0;32m📋 .ai/rules.md copied to clipboard!\033[0m"
        elif command -v xclip >/dev/null 2>&1; then
            cat "$project_root/.ai/rules.md" | xclip -selection clipboard
            echo "\033[0;32m📋 .ai/rules.md copied to clipboard!\033[0m"
        fi
    fi
    [[ -f "$context_file" ]] && echo "\033[0;32m📝 Promptable context file:\033[0m $context_file"
    echo "------------------------------------------"
    echo "\033[1;33m🚀 Start Claude Code with: claude\033[0m"
}

alias cc="claude-start"
alias vault-breakdown="$HOME/.ai-shadow-vault/bin/vault-breakdown"

function check_ai_cache() {
    local project_root="$PWD"
    while [[ "$project_root" != "/" && ! -d "$project_root/.ai" ]]; do
        project_root=$(dirname "$project_root")
    done

    if [[ -d "$project_root/.ai" ]]; then
        echo "\033[0;32m🛡️  AI Cache active!\033[0m (Run 'cc' to start)"
    fi
}

# --- Auto-execution & Path Setup ---
case ":$PATH:" in
    *":$HOME/.ai-shadow-vault/bin:"*) ;;
    *) export PATH="$HOME/.ai-shadow-vault/bin:$PATH" ;;
esac

autoload -U add-zsh-hook
add-zsh-hook -D chpwd set_gemini_context 2>/dev/null || true
add-zsh-hook -D chpwd check_ai_cache 2>/dev/null || true
add-zsh-hook chpwd set_gemini_context
add-zsh-hook chpwd check_ai_cache
set_gemini_context
check_ai_cache

# Aliases
alias vault-skills="$HOME/.ai-shadow-vault/scripts/install_skills.sh"
