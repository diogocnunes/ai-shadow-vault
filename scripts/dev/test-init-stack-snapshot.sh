#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

assert_contains() {
    local needle="$1"
    local file="$2"

    if ! grep -Fq -- "$needle" "$file"; then
        echo "Expected to find '$needle' in $file" >&2
        exit 1
    fi
}

assert_not_contains() {
    local needle="$1"
    local file="$2"

    if grep -Fq -- "$needle" "$file"; then
        echo "Did not expect to find '$needle' in $file" >&2
        exit 1
    fi
}

write_config() {
    local home_dir="$1"
    local rtk="${2:-false}"
    local superpowers="${3:-false}"
    local context_mode="${4:-false}"
    local use_superpowers_docs="${5:-false}"

    mkdir -p "$home_dir/.config/ai-shadow-vault"
    cat >"$home_dir/.config/ai-shadow-vault/config.json" <<JSON
{
  "vault_base_path": "$home_dir/.ai-shadow-vault-data",
  "default_adapters": ["CLAUDE.md", "AGENTS.md", "GEMINI.md"],
  "extras": {
    "rtk_instructions": $rtk,
    "superpowers_instructions": $superpowers,
    "context_mode_instructions": $context_mode,
    "use_superpowers_docs": $use_superpowers_docs
  }
}
JSON
}

run_init() {
    local home_dir="$1"

    HOME="$home_dir" "$ROOT_DIR/bin/ai-vault" init >/dev/null
}

resolve_path() {
    local target="$1"
    (
        cd "$target" >/dev/null 2>&1 && pwd -P
    )
}

build_path_without_python() {
    local fake_bin="$1"
    local command_name target

    mkdir -p "$fake_bin"
    for command_name in awk basename cat cmp cp cut date diff dirname find git grep head ln mkdir mktemp mv pwd rm sed shasum touch tr; do
        target="$(command -v "$command_name")"
        ln -sf "$target" "$fake_bin/$command_name"
    done

}

PROJECT_DIR="$WORK_DIR/project"
HOME_DIR="$WORK_DIR/home"
mkdir -p "$PROJECT_DIR" "$HOME_DIR"

cat >"$PROJECT_DIR/composer.json" <<'JSON'
{
  "require": {
    "php": "^8.4",
    "laravel/framework": "^12.0",
    "laravel/nova": "^5.0",
    "filament/forms": "^4.0"
  },
  "require-dev": {
    "pestphp/pest": "^3.8"
  }
}
JSON

cat >"$PROJECT_DIR/package.json" <<'JSON'
{
  "dependencies": {
    "vue": "^3.5",
    "@quasar/extras": "^1.0",
    "primevue": "^4.3"
  },
  "devDependencies": {
    "@playwright/test": "^1.55.0"
  }
}
JSON

write_config "$HOME_DIR"
cd "$PROJECT_DIR"
run_init "$HOME_DIR"

CLAUDE_FILE="$PROJECT_DIR/CLAUDE.md"
AGENTS_FILE="$PROJECT_DIR/AGENTS.md"
GEMINI_FILE="$PROJECT_DIR/GEMINI.md"
assert_contains "## Output & language" "$AGENTS_FILE"
assert_contains "## Working rules" "$AGENTS_FILE"
assert_contains "## Git" "$AGENTS_FILE"
assert_contains "## Laravel conventions" "$AGENTS_FILE"
assert_contains "- User-facing strings go through the project's lang files" "$AGENTS_FILE"
assert_contains "## Stack" "$AGENTS_FILE"
assert_contains "### Backend" "$AGENTS_FILE"
assert_contains "- PHP ^8.4" "$AGENTS_FILE"
assert_contains "- Laravel ^12.0" "$AGENTS_FILE"
assert_contains "- Laravel Nova ^5.0" "$AGENTS_FILE"
assert_contains "- Filament" "$AGENTS_FILE"
assert_not_contains "- Filament ^" "$AGENTS_FILE"
assert_contains "### Frontend / UI" "$AGENTS_FILE"
assert_contains "- Vue ^3.5" "$AGENTS_FILE"
assert_contains "- Quasar" "$AGENTS_FILE"
assert_not_contains "- Quasar ^" "$AGENTS_FILE"
assert_contains "- PrimeVue ^4.3" "$AGENTS_FILE"
assert_contains "### Testing" "$AGENTS_FILE"
assert_contains "- Pest ^3.8" "$AGENTS_FILE"
assert_contains "- Playwright ^1.55.0" "$AGENTS_FILE"
assert_not_contains "## Plugins" "$AGENTS_FILE"
assert_contains "@AGENTS.md" "$CLAUDE_FILE"
assert_contains "## Claude Code only" "$CLAUDE_FILE"
assert_contains "enforced deterministically in .claude/settings.json" "$CLAUDE_FILE"
assert_not_contains "/cost" "$CLAUDE_FILE"
assert_not_contains "## Plugins" "$CLAUDE_FILE"
assert_contains "## Output & language" "$GEMINI_FILE"
assert_contains "## Working rules" "$GEMINI_FILE"
assert_not_contains "/cost" "$GEMINI_FILE"

DOCS_DIR="$PROJECT_DIR/.ai/docs"
assert_contains "# AI Docs Index" "$DOCS_DIR/index.md"
assert_contains "# Autoload Policy" "$DOCS_DIR/core/autoload-policy.md"
assert_contains "## Never Auto-Load" "$DOCS_DIR/core/autoload-policy.md"
assert_contains "learnings/laravel/*" "$DOCS_DIR/index.md"
assert_contains "learnings/node/*" "$DOCS_DIR/index.md"

FIRST_HASH="$(shasum -a 256 "$CLAUDE_FILE" | awk '{print $1}')"
run_init "$HOME_DIR"
SECOND_HASH="$(shasum -a 256 "$CLAUDE_FILE" | awk '{print $1}')"
if [[ "$FIRST_HASH" != "$SECOND_HASH" ]]; then
    echo "Expected byte-stable adapter output across repeated init runs." >&2
    exit 1
fi

BROKEN_HOME_DIR="$WORK_DIR/home-no-python"
BROKEN_PROJECT_DIR="$WORK_DIR/project-no-python"
mkdir -p "$BROKEN_HOME_DIR" "$BROKEN_PROJECT_DIR"
write_config "$BROKEN_HOME_DIR"

cat >"$BROKEN_PROJECT_DIR/composer.json" <<'JSON'
{
  "require": {
    "php": "^8.4",
    "laravel/framework": "^12.0"
  }
}
JSON

cat >"$BROKEN_PROJECT_DIR/package.json" <<'JSON'
{
  "dependencies": {
    "vue": "^3.5"
  }
}
JSON

cd "$BROKEN_PROJECT_DIR"
FAKE_BIN="$WORK_DIR/no-python-bin"
build_path_without_python "$FAKE_BIN"
HOME="$BROKEN_HOME_DIR" PATH="$FAKE_BIN" "$ROOT_DIR/bin/ai-vault" init >/dev/null

assert_not_contains "## Stack" "$BROKEN_PROJECT_DIR/AGENTS.md"

PLUGIN_HOME_DIR="$WORK_DIR/home-plugins"
PLUGIN_PROJECT_DIR="$WORK_DIR/project-plugins"
mkdir -p "$PLUGIN_HOME_DIR" "$PLUGIN_PROJECT_DIR"
write_config "$PLUGIN_HOME_DIR" false true true true

mkdir -p "$PLUGIN_HOME_DIR/.codex/plugins/cache/openai-curated/superpowers/test/.codex-plugin"
cat >"$PLUGIN_HOME_DIR/.codex/plugins/cache/openai-curated/superpowers/test/.codex-plugin/plugin.json" <<'JSON'
{ "name": "superpowers", "version": "1.0.0" }
JSON
mkdir -p "$PLUGIN_HOME_DIR/.config/opencode"
cat >"$PLUGIN_HOME_DIR/.config/opencode/opencode.json" <<'JSON'
{ "plugin": ["context-mode", "superpowers@git+https://example.org/superpowers.git"] }
JSON

cat >"$PLUGIN_PROJECT_DIR/composer.json" <<'JSON'
{ "require": { "php": "^8.4" } }
JSON

cd "$PLUGIN_PROJECT_DIR"
git init >/dev/null 2>&1
run_init "$PLUGIN_HOME_DIR"
assert_contains "## Output & language" "$PLUGIN_PROJECT_DIR/AGENTS.md"
assert_contains "## Working rules" "$PLUGIN_PROJECT_DIR/AGENTS.md"
assert_not_contains "## Plugins" "$PLUGIN_PROJECT_DIR/AGENTS.md"

if [[ "$(resolve_path "$PLUGIN_PROJECT_DIR/.ai/docs")" != "$(resolve_path "$PLUGIN_PROJECT_DIR/docs/superpowers/specs")" ]]; then
    echo "Expected .ai/docs to point to docs/superpowers/specs" >&2
    exit 1
fi
if [[ "$(resolve_path "$PLUGIN_PROJECT_DIR/.ai/plans")" != "$(resolve_path "$PLUGIN_PROJECT_DIR/docs/superpowers/plans")" ]]; then
    echo "Expected .ai/plans to point to docs/superpowers/plans" >&2
    exit 1
fi
assert_contains "/docs/superpowers/" "$PLUGIN_PROJECT_DIR/.git/info/exclude"

PLUGIN_OFF_HOME_DIR="$WORK_DIR/home-plugins-off"
PLUGIN_OFF_PROJECT_DIR="$WORK_DIR/project-plugins-off"
mkdir -p "$PLUGIN_OFF_HOME_DIR" "$PLUGIN_OFF_PROJECT_DIR"
write_config "$PLUGIN_OFF_HOME_DIR" false false false false
mkdir -p "$PLUGIN_OFF_HOME_DIR/.config/opencode"
cat >"$PLUGIN_OFF_HOME_DIR/.config/opencode/opencode.json" <<'JSON'
{
  "plugin": [
    "context-mode",
    "superpowers@git+https://example.org/superpowers.git"
  ]
}
JSON
cat >"$PLUGIN_OFF_PROJECT_DIR/composer.json" <<'JSON'
{ "require": { "php": "^8.4" } }
JSON
cd "$PLUGIN_OFF_PROJECT_DIR"
run_init "$PLUGIN_OFF_HOME_DIR"
assert_not_contains "## Plugins" "$PLUGIN_OFF_PROJECT_DIR/AGENTS.md"

CLAUDE_NS_HOME_DIR="$WORK_DIR/home-claude-ns"
CLAUDE_NS_PROJECT_DIR="$WORK_DIR/project-claude-ns"
mkdir -p "$CLAUDE_NS_HOME_DIR" "$CLAUDE_NS_PROJECT_DIR"
write_config "$CLAUDE_NS_HOME_DIR" false true false false
mkdir -p "$CLAUDE_NS_HOME_DIR/.claude/plugins"
cat >"$CLAUDE_NS_HOME_DIR/.claude/plugins/installed_plugins.json" <<'JSON'
{
  "plugins": {
    "superpowers@marketplace": {"version": "2.0.0"}
  }
}
JSON
cat >"$CLAUDE_NS_PROJECT_DIR/composer.json" <<'JSON'
{ "require": { "php": "^8.4" } }
JSON
cd "$CLAUDE_NS_PROJECT_DIR"
git init >/dev/null 2>&1
run_init "$CLAUDE_NS_HOME_DIR"
assert_contains "@AGENTS.md" "$CLAUDE_NS_PROJECT_DIR/CLAUDE.md"
assert_contains "## Claude Code only" "$CLAUDE_NS_PROJECT_DIR/CLAUDE.md"
assert_contains "@use superpowers. Activate the subagents and skills needed for the task." "$CLAUDE_NS_PROJECT_DIR/CLAUDE.md"
assert_contains "enforced deterministically in .claude/settings.json" "$CLAUDE_NS_PROJECT_DIR/CLAUDE.md"
assert_not_contains "Talk like caveman" "$CLAUDE_NS_PROJECT_DIR/CLAUDE.md"
assert_not_contains "## Plugins" "$CLAUDE_NS_PROJECT_DIR/CLAUDE.md"

CLAUDE_NS_VAULT_DIR="$CLAUDE_NS_HOME_DIR/.ai-shadow-vault-data"
CLAUDE_NS_VAULT_PROJECT="$(ls "$CLAUDE_NS_VAULT_DIR" | head -1)"
CLAUDE_NS_GEMINI_VAULT="$CLAUDE_NS_VAULT_DIR/$CLAUDE_NS_VAULT_PROJECT/GEMINI.md"
CLAUDE_NS_AGENTS_VAULT="$CLAUDE_NS_VAULT_DIR/$CLAUDE_NS_VAULT_PROJECT/AGENTS.md"
if [[ ! -L "$CLAUDE_NS_GEMINI_VAULT" ]]; then
    echo "Expected $CLAUDE_NS_GEMINI_VAULT to be a symlink" >&2
    exit 1
fi
if [[ "$(resolve_path "$CLAUDE_NS_GEMINI_VAULT")" != "$(resolve_path "$CLAUDE_NS_AGENTS_VAULT")" ]]; then
    echo "Expected vault/GEMINI.md to resolve to the same path as vault/AGENTS.md" >&2
    exit 1
fi

STALE_HOME_DIR="$WORK_DIR/home-stale"
STALE_PROJECT_DIR="$WORK_DIR/project-stale"
mkdir -p "$STALE_HOME_DIR/.config/ai-shadow-vault" "$STALE_PROJECT_DIR"
cat >"$STALE_HOME_DIR/.config/ai-shadow-vault/config.json" <<JSON
{
  "vault_base_path": "$STALE_HOME_DIR/.ai-shadow-vault-data",
  "default_adapters": ["CLAUDE.md", "AGENTS.md", "GEMINI.md"],
  "extras": {
    "rtk_instructions": false
  }
}
JSON
cat >"$STALE_PROJECT_DIR/composer.json" <<'JSON'
{ "require": { "php": "^8.4" } }
JSON
cd "$STALE_PROJECT_DIR"
git init >/dev/null 2>&1
STALE_OUTPUT="$(HOME="$STALE_HOME_DIR" "$ROOT_DIR/bin/ai-vault" init 2>&1)"
if ! grep -q "Config schema outdated" <<<"$STALE_OUTPUT"; then
    echo "Expected 'Config schema outdated' warning in init output" >&2
    echo "Got: $STALE_OUTPUT" >&2
    exit 1
fi
if ! grep -q "Run 'ai-vault install'" <<<"$STALE_OUTPUT"; then
    echo "Expected 'Run ai-vault install' hint in init output" >&2
    exit 1
fi

echo "test-init-stack-snapshot.sh: ok"
