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

## 💾 Session Context Management
**MANDATORY:** You must maintain a running log of your activities in `.ai/session.md`.
1. Use `.ai/session-template.md` to initialize it if it doesn't exist.
2. Update it after every significant change or milestone.
3. When the user says "Save context", "Wrap up", or "Checkpoint":
    - Ensure `.ai/session.md` is complete and accurate.
    - Execute `scripts/vault-ai-save.sh`.

**User Triggers:** "New Session", "Start fresh", "Init AI"
**Action:**
1. Execute `scripts/vault-ai-init.sh` (or `bin/vault-ai-init`).

## 🛡️ Git Safety
- Never suggest committing files inside `.ai/` or `.claude/`.
- Ensure all AI-generated context remains in the vault via symlinks.
