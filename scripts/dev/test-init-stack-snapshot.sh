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

    mkdir -p "$home_dir/.config/ai-shadow-vault"
    cat >"$home_dir/.config/ai-shadow-vault/config.json" <<JSON
{
  "vault_base_path": "$home_dir/.ai-shadow-vault-data",
  "default_adapters": ["CLAUDE.md", "AGENTS.md", "GEMINI.md"],
  "extras": {
    "rtk_instructions": false
  }
}
JSON
}

run_init() {
    local home_dir="$1"

    HOME="$home_dir" "$ROOT_DIR/bin/ai-vault" init >/dev/null
}

build_path_without_python() {
    local fake_bin="$1"
    local command_name target

    mkdir -p "$fake_bin"
    for command_name in awk basename cat cmp cp cut date diff dirname find git head ln mkdir mktemp mv pwd rm sed shasum touch tr; do
        target="$(command -v "$command_name")"
        ln -sf "$target" "$fake_bin/$command_name"
    done

    if command -v realpath >/dev/null 2>&1; then
        ln -sf "$(command -v realpath)" "$fake_bin/realpath"
    fi
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
assert_contains "## Stack Snapshot" "$CLAUDE_FILE"
assert_contains "### Backend" "$CLAUDE_FILE"
assert_contains "- PHP ^8.4" "$CLAUDE_FILE"
assert_contains "- Laravel ^12.0" "$CLAUDE_FILE"
assert_contains "- Laravel Nova ^5.0" "$CLAUDE_FILE"
assert_contains "- Filament" "$CLAUDE_FILE"
assert_not_contains "- Filament ^" "$CLAUDE_FILE"
assert_contains "### Frontend / UI" "$CLAUDE_FILE"
assert_contains "- Vue ^3.5" "$CLAUDE_FILE"
assert_contains "- Quasar" "$CLAUDE_FILE"
assert_not_contains "- Quasar ^" "$CLAUDE_FILE"
assert_contains "- PrimeVue ^4.3" "$CLAUDE_FILE"
assert_contains "### Testing" "$CLAUDE_FILE"
assert_contains "- Pest ^3.8" "$CLAUDE_FILE"
assert_contains "- Playwright ^1.55.0" "$CLAUDE_FILE"

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

assert_not_contains "## Stack Snapshot" "$BROKEN_PROJECT_DIR/CLAUDE.md"

echo "test-init-stack-snapshot.sh: ok"
