#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/vault-resolver.sh"
source "$SCRIPT_DIR/lib/extensions-resolver.sh"

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

usage() {
    cat <<EOF
Usage:
  vault-review --scope working
  vault-review --scope staged
  vault-review --scope branch --base <branch>
  vault-review --scope commit --commit <sha>
  vault-review --scope range --from <sha> --to <sha>

Aliases:
  vault-code-review
  vault-pr-review
EOF
}

run_bootstrap_preflight() {
    if [[ "${BOOTSTRAP_RUNNING:-0}" == "1" ]]; then
        return 0
    fi

    if [[ -x "$SCRIPT_DIR/vault-bootstrap.sh" ]]; then
        "$SCRIPT_DIR/vault-bootstrap.sh" ensure
        return $?
    fi

    if command -v vault-bootstrap >/dev/null 2>&1; then
        vault-bootstrap ensure
        return $?
    fi

    echo -e "${RED}vault-bootstrap command not found.${NC}"
    exit 1
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

require_git_repo() {
    if ! git -C "$PROJECT_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
        echo -e "${RED}vault-review requires a Git repository.${NC}"
        exit 1
    fi
}

ensure_ai_subdir() {
    local target_dir="$1"

    if mkdir -p "$target_dir" 2>/dev/null; then
        return 0
    fi

    echo -e "${RED}Could not create required directory:${NC} $target_dir"
    echo -e "${YELLOW}Check whether .ai points to a vault location that is writable in this environment.${NC}"
    exit 1
}

ensure_commit_exists() {
    local ref="$1"

    if ! git -C "$PROJECT_ROOT" rev-parse --verify "${ref}^{commit}" >/dev/null 2>&1; then
        echo -e "${RED}Invalid commit reference:${NC} $ref"
        exit 1
    fi
}

timestamp_utc() {
    date -u +"%Y%m%d-%H%M%S"
}

slugify_label() {
    printf '%s\n' "$1" | tr '/:@ ' '-' | sed -E 's/[^[:alnum:]._-]+/-/g; s/-+/-/g; s/^-+//; s/-+$//'
}

SCOPE=""
BASE_BRANCH=""
COMMIT_REF=""
FROM_REF=""
TO_REF=""

while [[ "$#" -gt 0 ]]; do
    case "${1:-}" in
        --scope)
            shift
            SCOPE="${1:-}"
            ;;
        --base)
            shift
            BASE_BRANCH="${1:-}"
            ;;
        --commit)
            shift
            COMMIT_REF="${1:-}"
            ;;
        --from)
            shift
            FROM_REF="${1:-}"
            ;;
        --to)
            shift
            TO_REF="${1:-}"
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown argument:${NC} ${1:-}"
            usage
            exit 1
            ;;
    esac
    shift || true
done

if [[ -z "$SCOPE" ]]; then
    usage
    exit 1
fi

PROJECT_ROOT="$(vault_resolve_project_root "$PWD")"
AI_DIR="$PROJECT_ROOT/.ai"

vault_extension_notice_if_disabled "$PROJECT_ROOT" "review" "vault-review" || true

if [[ ! -d "$AI_DIR" ]]; then
    echo -e "${YELLOW}No .ai directory found in project tree. Run vault-init first.${NC}"
    exit 1
fi

run_bootstrap_preflight

require_git_repo

ensure_ai_subdir "$AI_DIR/reviews"

REVIEW_LABEL=""
DIFF_COMMAND=""
SCOPE_DESCRIPTION=""

case "$SCOPE" in
    working)
        REVIEW_LABEL="working-tree"
        DIFF_COMMAND="git diff HEAD"
        SCOPE_DESCRIPTION="All uncommitted changes relative to HEAD."
        ;;
    staged)
        REVIEW_LABEL="staged"
        DIFF_COMMAND="git diff --cached"
        SCOPE_DESCRIPTION="Only staged changes."
        ;;
    branch)
        if [[ -z "$BASE_BRANCH" ]]; then
            echo -e "${RED}Missing required argument:${NC} --base <branch>"
            exit 1
        fi
        BASE_REF="$BASE_BRANCH"
        if git -C "$PROJECT_ROOT" show-ref --verify --quiet "refs/heads/$BASE_BRANCH"; then
            BASE_REF="$BASE_BRANCH"
        elif git -C "$PROJECT_ROOT" show-ref --verify --quiet "refs/remotes/origin/$BASE_BRANCH"; then
            BASE_REF="origin/$BASE_BRANCH"
        elif ! git -C "$PROJECT_ROOT" rev-parse --verify "$BASE_BRANCH" >/dev/null 2>&1; then
            echo -e "${RED}Base branch not found:${NC} $BASE_BRANCH"
            exit 1
        fi
        MERGE_BASE="$(git -C "$PROJECT_ROOT" merge-base HEAD "$BASE_REF")"
        REVIEW_LABEL="branch-vs-$(slugify_label "$BASE_BRANCH")"
        DIFF_COMMAND="git diff $MERGE_BASE...HEAD"
        SCOPE_DESCRIPTION="Current branch compared to merge base with $BASE_REF ($MERGE_BASE)."
        ;;
    commit)
        if [[ -z "$COMMIT_REF" ]]; then
            echo -e "${RED}Missing required argument:${NC} --commit <sha>"
            exit 1
        fi
        ensure_commit_exists "$COMMIT_REF"
        COMMIT_SHA="$(git -C "$PROJECT_ROOT" rev-parse --short "$COMMIT_REF")"
        REVIEW_LABEL="commit-$COMMIT_SHA"
        DIFF_COMMAND="git show $COMMIT_REF"
        SCOPE_DESCRIPTION="Changes introduced by commit $COMMIT_SHA."
        ;;
    range)
        if [[ -z "$FROM_REF" || -z "$TO_REF" ]]; then
            echo -e "${RED}Missing required arguments:${NC} --from <sha> --to <sha>"
            exit 1
        fi
        ensure_commit_exists "$FROM_REF"
        ensure_commit_exists "$TO_REF"
        FROM_SHA="$(git -C "$PROJECT_ROOT" rev-parse --short "$FROM_REF")"
        TO_SHA="$(git -C "$PROJECT_ROOT" rev-parse --short "$TO_REF")"
        REVIEW_LABEL="range-$FROM_SHA-$TO_SHA"
        DIFF_COMMAND="git diff $FROM_REF..$TO_REF"
        SCOPE_DESCRIPTION="Changes between $FROM_SHA and $TO_SHA."
        ;;
    *)
        echo -e "${RED}Unsupported scope:${NC} $SCOPE"
        usage
        exit 1
        ;;
esac

(
    cd "$PROJECT_ROOT"
    "$SCRIPT_DIR/vault-ai-context-file.sh" >/dev/null
)

TIMESTAMP="$(timestamp_utc)"
OUTPUT_PATH="$PROJECT_ROOT/.ai/reviews/$TIMESTAMP-$REVIEW_LABEL.review.md"

PROMPT=$(cat <<EOF
SESSION PREAMBLE (MANDATORY):
- Run bootstrap checks from CLAUDE.md contract before task execution.
- Output: \`BOOTSTRAP_ACK: rules+context loaded\` before task execution.
- BOOTSTRAP_ACK is an audit signal only (not a technical guarantee).

Use \`.ai/context/agent-context.md\` as the current project summary.
Use \`.ai/skills/ACTIVE_SKILLS.md\` for any active specialized guidance.
Then invoke the \`code-review\` skill for this scope:

- Scope: $SCOPE
- Description: $SCOPE_DESCRIPTION
- Git command: \`$DIFF_COMMAND\`
- Output path: \`.ai/reviews/$(basename "$OUTPUT_PATH")\`

Requirements:
- Review only. Do not implement fixes.
- Analyze the repository before writing findings.
- Use project rules and active skills before generic advice.
- Write the full review to \`.ai/reviews/$(basename "$OUTPUT_PATH")\`.
- Include a short "What Was Done Well" section before findings.
- Use severity levels: Critical, Warning, Suggestion.
- End with a summary table and mark non-applicable categories as \`N/A\`.
EOF
)

"$SCRIPT_DIR/vault-bootstrap.sh" ack --source vault-review >/dev/null 2>&1 || true

echo -e "${BLUE}Code review prepared.${NC}"
echo "Project Root: $PROJECT_ROOT"
echo "Scope: $SCOPE"
echo "Output Path: $OUTPUT_PATH"
echo
copy_prompt "$PROMPT"
echo
echo "Suggested prompt:"
echo "------------------------------------------"
printf '%s\n' "$PROMPT"
echo "------------------------------------------"
echo
echo -e "${GREEN}Run your agent with the prompt above. Regenerate context afterward with vault-ai-context if the review leads to follow-up work.${NC}"
