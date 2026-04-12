# Minimal shell integration for AI Shadow Vault.

AI_SHADOW_SHELL_DIR="${${(%):-%N}:A:h}"
AI_SHADOW_ROOT="${AI_SHADOW_SHELL_DIR:h}"

case ":$PATH:" in
    *":$AI_SHADOW_ROOT/bin:"*) ;;
    *) export PATH="$AI_SHADOW_ROOT/bin:$PATH" ;;
esac

if [[ -f "$AI_SHADOW_ROOT/libexec/ai-vault/lib/resolver.sh" ]]; then
    source "$AI_SHADOW_ROOT/libexec/ai-vault/lib/resolver.sh"
fi
