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

declare -a REQUESTED_SKILLS=()

if [[ "$#" -gt 0 ]]; then
    REQUESTED_SKILLS=("$@")
else
    while IFS= read -r line; do
        [[ -n "$line" ]] && REQUESTED_SKILLS+=("$line")
    done < <(skills_load_active_names "$PROJECT_ROOT")
fi

mkdir -p "$STATE_DIR"

{
    echo "# Active Skills"
    echo
    echo "<!-- AI Shadow Vault: generated file. Rebuild with vault-skills sync or vault-ai-context. -->"
    echo
    echo "This file contains the currently active skill bundle for context-driven agents."
    echo
    echo "## Active Skill IDs"
    if [[ "${#REQUESTED_SKILLS[@]}" -eq 0 ]]; then
        echo "- No active skills selected."
    else
        resolved_line=""
        skill_name=""
        skill_file=""
        skill_desc=""
        for skill_name in "${REQUESTED_SKILLS[@]}"; do
            resolved_line="$(skills_resolve_one "$skill_name")"
            IFS=$'\t' read -r skill_name skill_file skill_desc <<< "$resolved_line"
            echo "- \`$skill_name\`"
        done
    fi
    echo
    echo "## Skill Details"

    if [[ "${#REQUESTED_SKILLS[@]}" -eq 0 ]]; then
        echo
        echo "No skills are active."
    else
        resolved_line=""
        skill_name=""
        skill_file=""
        skill_desc=""
        for skill_name in "${REQUESTED_SKILLS[@]}"; do
            resolved_line="$(skills_resolve_one "$skill_name")"
            IFS=$'\t' read -r skill_name skill_file skill_desc <<< "$resolved_line"
            echo
            echo "---"
            echo
            echo "### $skill_name"
            [[ -n "$skill_desc" ]] && echo "> $skill_desc"
            echo
            skills_strip_frontmatter "$skill_file"
        done
    fi
} > "$ACTIVE_BUNDLE_FILE"

echo "Generated active skills bundle at: $ACTIVE_BUNDLE_FILE"
