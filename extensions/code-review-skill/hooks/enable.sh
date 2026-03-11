#!/bin/bash

set -euo pipefail

PROJECT_ROOT="${AI_SHADOW_PROJECT_ROOT:-$PWD}"

mkdir -p "$PROJECT_ROOT/.ai/extensions"
cat > "$PROJECT_ROOT/.ai/extensions/code-review-skill.md" <<'EOF'
# code-review-skill

External optional package:

- Upstream: `felipereisdev/code-review-skill`
- Source: https://github.com/felipereisdev/code-review-skill

This package is tracked as an optional extension in AI Shadow Vault.
Use it when you want the upstream review workflow explicitly, instead of treating review as built-in product scope.

Local related workflow:

- `vault-ext enable review`
EOF
