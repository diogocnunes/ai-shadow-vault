#!/bin/bash

set -euo pipefail

PROJECT_ROOT="${AI_SHADOW_PROJECT_ROOT:-$PWD}"

mkdir -p "$PROJECT_ROOT/.ai/extensions"
cat > "$PROJECT_ROOT/.ai/extensions/user-stories-skill.md" <<'EOF'
# user-stories-skill

External optional package:

- Upstream: `felipereisdev/user-stories-skill`
- Source: https://github.com/felipereisdev/user-stories-skill

This package is tracked as an optional extension in AI Shadow Vault.
Use it when you want the upstream user-story workflow explicitly, instead of embedding it into the core package.

Local related workflow:

- `vault-ext enable planning`
EOF
