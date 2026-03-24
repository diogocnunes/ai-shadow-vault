#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/skills-resolver.sh"

if [[ "$#" -gt 0 && -d "$1" ]]; then
    PROJECT_ROOT="$(skills_project_root "$1")"
    shift
else
    PROJECT_ROOT="$(skills_project_root "$PWD")"
fi

ACTIVE_BUNDLE_FILE="$(skills_active_bundle_file "$PROJECT_ROOT")"
STATE_DIR="$(skills_ensure_state_dir "$PROJECT_ROOT")"

mkdir -p "$STATE_DIR"

declare -a REQUESTED_SKILLS=()

if [[ "$#" -gt 0 ]]; then
    REQUESTED_SKILLS=("$@")
else
    while IFS= read -r line; do
        [[ -n "$line" ]] && REQUESTED_SKILLS+=("$line")
    done < <(skills_load_active_names "$PROJECT_ROOT")
fi

{
    echo "<!-- AI-SHADOW-VAULT: MANAGED FILE -->"
    echo
    echo "# Active Skills (Index Only)"
    echo
    echo "<!-- AI Shadow Vault: generated file. Rebuild with vault-skills sync or vault-ai-context. -->"
    echo
    echo "This file lists active skill IDs only. Load full skill docs on demand."
    echo
    echo "## Active Skill IDs"
    if [[ "${#REQUESTED_SKILLS[@]}" -eq 0 ]]; then
        echo "- No active skills selected."
    else
        for skill_name in "${REQUESTED_SKILLS[@]}"; do
            resolved_line="$(skills_resolve_one "$skill_name")"
            IFS=$'\t' read -r resolved_name _ _ <<< "$resolved_line"
            echo "- \`$resolved_name\`"
        done
    fi

    echo
    echo "## Skill Index"
    echo "| Skill ID | Purpose | Source |"
    echo "|---|---|---|"

    if [[ "${#REQUESTED_SKILLS[@]}" -eq 0 ]]; then
        echo "| - | No active skills | - |"
    else
        for skill_name in "${REQUESTED_SKILLS[@]}"; do
            resolved_line="$(skills_resolve_one "$skill_name")"
            IFS=$'\t' read -r resolved_name skill_file skill_desc <<< "$resolved_line"
            source_ref="templates/Skills/$(basename "$skill_file")"
            purpose="$skill_desc"
            if [[ -z "$purpose" ]]; then
                purpose="No description provided"
            fi
            echo "| \`$resolved_name\` | $purpose | \`$source_ref\` |"
        done
    fi

    echo
    echo "Rules:"
    echo "- Keep this file compact."
    echo "- Do not embed full skill manuals here."
} > "$ACTIVE_BUNDLE_FILE"

echo "Generated active skills index at: $ACTIVE_BUNDLE_FILE"
