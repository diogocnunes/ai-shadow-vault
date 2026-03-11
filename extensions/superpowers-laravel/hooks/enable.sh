#!/bin/bash

set -euo pipefail

PROJECT_ROOT="${AI_SHADOW_PROJECT_ROOT:-$PWD}"

mkdir -p "$PROJECT_ROOT/.ai/extensions"
cat > "$PROJECT_ROOT/.ai/extensions/superpowers-laravel.md" <<'EOF'
# superpowers-laravel

External optional package:

- Upstream: `jpcaparas/superpowers-laravel`
- Source: https://github.com/jpcaparas/superpowers-laravel

This package is tracked as an optional extension in AI Shadow Vault.
Use it when you want Laravel-specific superpowers to remain external to the core package.

Local related workflows:

- `vault-ext enable skills`
- `vault-ext enable laravel-stack`
EOF
