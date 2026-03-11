#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/vault-resolver.sh"
source "$SCRIPT_DIR/lib/extensions-resolver.sh"

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

usage() {
    cat <<EOF
Usage:
  vault-user-stories "<goal description>"

Example:
  vault-user-stories "Implement OAuth login"
EOF
}

slugify_goal() {
    printf '%s\n' "$1" \
        | tr '[:upper:]' '[:lower:]' \
        | sed -E 's/[^[:alnum:][:space:]-]+/ /g' \
        | awk '
            BEGIN {
                split("a an the um uma o os as", stopwords, " ")
                for (i in stopwords) {
                    blocked[stopwords[i]] = 1
                }
                count = 0
            }
            {
                for (i = 1; i <= NF; i++) {
                    if ($i in blocked) {
                        continue
                    }
                    words[++count] = $i
                }
            }
            END {
                limit = count < 5 ? count : 5
                for (i = 1; i <= limit; i++) {
                    printf "%s%s", words[i], (i < limit ? "-" : "")
                }
                if (limit == 0) {
                    printf "plan"
                }
                printf "\n"
            }
        ' \
        | sed -E 's/-+/-/g; s/^-+//; s/-+$//'
}

copy_prompt() {
    local content="$1"

    if command -v pbcopy >/dev/null 2>&1; then
        if printf '%s' "$content" | pbcopy; then
            echo -e "${GREEN}Prompt copied to clipboard with pbcopy.${NC}"
            return
        fi
    fi

    if command -v xclip >/dev/null 2>&1; then
        if printf '%s' "$content" | xclip -selection clipboard; then
            echo -e "${GREEN}Prompt copied to clipboard with xclip.${NC}"
            return
        fi
    fi

    echo -e "${YELLOW}Clipboard tool not found. Copy the prompt manually.${NC}"
}

GOAL="${*:-}"

if [[ -z "$GOAL" ]]; then
    usage
    exit 1
fi

PROJECT_ROOT="$(vault_resolve_project_root "$PWD")"
AI_DIR="$PROJECT_ROOT/.ai"

vault_extension_notice_if_disabled "$PROJECT_ROOT" "planning" "vault-user-stories" || true

if [[ ! -d "$AI_DIR" ]]; then
    echo -e "${YELLOW}No .ai directory found in project tree. Run vault-init first.${NC}"
    exit 1
fi

mkdir -p "$AI_DIR/plans"

(
    cd "$PROJECT_ROOT"
    "$SCRIPT_DIR/vault-ai-context-file.sh" >/dev/null
)

SLUG="$(slugify_goal "$GOAL")"
OUTPUT_PATH="$PROJECT_ROOT/.ai/plans/$SLUG.user-stories.md"

PROMPT=$(cat <<EOF
Use \`.ai/context/agent-context.md\` as the current project summary.
Use \`.ai/skills/ACTIVE_SKILLS.md\` for any active specialized guidance.
Then invoke the \`user-stories\` skill for this goal:

"$GOAL"

Requirements:
- Planning only. Do not implement anything.
- Analyze the repository before writing the plan.
- Write the output to \`.ai/plans/$SLUG.user-stories.md\`.
- Produce 3-10 atomic user stories with acceptance criteria, dependencies, complexity, filesToTouch, implementation notes, and a definition of done.
EOF
)

echo -e "${BLUE}User stories planning prepared.${NC}"
echo "Project Root: $PROJECT_ROOT"
echo "Goal: $GOAL"
echo "Output Path: $OUTPUT_PATH"
echo
copy_prompt "$PROMPT"
echo
echo "Suggested prompt:"
echo "------------------------------------------"
printf '%s\n' "$PROMPT"
echo "------------------------------------------"
echo
echo -e "${GREEN}Run your agent with the prompt above. Regenerate context afterward with vault-ai-context once the plan is created.${NC}"
