# Claude Project Rules

## 🚀 Query Priority
**MANDATORY:** You must check the local cache and project documentation before making any external queries or assumptions.
1. **Search local `.ai/cache/`** for previous solutions.
2. **Search local `.ai/docs/`** for project-specific patterns.
3. **Search local `.ai/plans/`** for ongoing work.
4. **Only then** use external tools or general knowledge.

## 🏁 Mandatory Session Start
At the beginning of every session:
1. Load and review `.ai/rules.md`.
2. Check `.ai/plans/` for the current roadmap.
3. If no active session exists, propose creating one using `.ai/session-template.md`.

## 🛡️ Git Safety
- Never suggest committing files inside `.ai/` or `.claude/`.
- Ensure all AI-generated context remains in the vault via symlinks.
