#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${AI_SHADOW_PROJECT_ROOT:-$PWD}"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

mkdir -p "$PROJECT_ROOT/.ai/agents"
cp "$REPO_ROOT/templates/agents/user-stories.sh" "$PROJECT_ROOT/.ai/agents/user-stories.sh"
chmod +x "$PROJECT_ROOT/.ai/agents/user-stories.sh"
