<!-- AI-SHADOW-VAULT: MANAGED FILE -->

# Vault Hygiene Rules

## Core Hygiene
- No duplication of policy across files.
- No context inflation in active files.
- No archive content in active context.
- No drift between adapter files and canonical rules.

## Active vs Archive
- Active: `.ai/rules.md`, `.ai/context/*.md`, `.ai/plans/`, `.ai/skills/ACTIVE_SKILLS.md`, `.ai/docs/`.
- Archive: `.ai/archive/` for historical records only.

## Agent Adapter Consistency
- `AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, `.cursorrules`, `.windsurfrules`, and `copilot-instructions.md` stay thin and non-authoritative.
- They must not define conflicting policy.

## Tool Handling
- Optional tools must never appear as hard requirements.
- Fallback behavior must be defined inline where used.
- Removing a tool must not break any vault file.
