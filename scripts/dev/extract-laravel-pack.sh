#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET_DIR="${1:-}"

if [[ -z "$TARGET_DIR" ]]; then
    echo "Usage: scripts/dev/extract-laravel-pack.sh <target-pack-repo-dir>" >&2
    exit 1
fi

mkdir -p "$TARGET_DIR/skills"

copy_if_exists() {
    local source_file="$1"
    local target_file="$2"
    if [[ -f "$source_file" ]]; then
        cp "$source_file" "$target_file"
        echo "copied: $source_file -> $target_file"
    fi
}

copy_if_exists "$ROOT_DIR/templates/Skills/BACKEND-EXPERT.md" "$TARGET_DIR/skills/backend-expert.md"
copy_if_exists "$ROOT_DIR/templates/Skills/FILAMENT-V5.md" "$TARGET_DIR/skills/filament-v5.md"
copy_if_exists "$ROOT_DIR/templates/Skills/ARCHITECT-LEAD.md" "$TARGET_DIR/skills/architect-lead.md"
copy_if_exists "$ROOT_DIR/templates/Skills/ARCHITECT-FILAMENT-LEAD.md" "$TARGET_DIR/skills/architect-filament-lead.md"
copy_if_exists "$ROOT_DIR/templates/Skills/TALL-STACK.md" "$TARGET_DIR/skills/tall-stack.md"
copy_if_exists "$ROOT_DIR/templates/Skills/LARAVEL-CODE-QUALITY.md" "$TARGET_DIR/skills/laravel-code-quality.md"
copy_if_exists "$ROOT_DIR/templates/Skills/LEGACY-MIGRATION-SPECIALIST.md" "$TARGET_DIR/skills/legacy-migration-specialist.md"

if [[ ! -f "$TARGET_DIR/pack.json" ]]; then
    cat > "$TARGET_DIR/pack.json" <<'PACKJSON'
{
  "name": "ai-shadow-vault-laravel",
  "version": "1.0.0",
  "description": "Official Laravel skill pack",
  "core_api": ">=2.1.0 <3.0.0",
  "capabilities": ["skills"]
}
PACKJSON
    echo "created: $TARGET_DIR/pack.json"
fi

echo "Extraction complete. Next: run vault-pack validate $TARGET_DIR"
