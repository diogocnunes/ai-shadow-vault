<!-- AI-SHADOW-VAULT: MANAGED FILE -->

# Vault Rules (Canonical Policy)

## 1) Authority
Use sources in this order:
1. `.ai/rules.md`
2. `.ai/context/current-task.md`
3. `.ai/plans/`
4. `.ai/context/project-context.md`
5. `.ai/context/agent-context.md`
6. `.ai/skills/ACTIVE_SKILLS.md`
7. `.ai/docs/`
8. `.ai/archive/` (manual lookup only)

Project context is evaluated before agent context so stable facts frame session state.

## 2) Separation of Concerns
- Policy: `.ai/rules.md` only.
- Stable project facts: `.ai/context/project-context.md`.
- Working-state continuity: `.ai/context/agent-context.md`.
- Single active task: `.ai/context/current-task.md`.
- Active plans: `.ai/plans/`.
- Skills index: `.ai/skills/ACTIVE_SKILLS.md`.
- Durable references: `.ai/docs/`.
- History: `.ai/archive/`.

## 3) Task Lifecycle
- `current-task.md` holds one active task only.
- `current-task.md` must declare `mode: plan|execute` in frontmatter.
- Completed tasks are cleared or archived.
- Active context must never accumulate history.

## 4) Active Context Hygiene
- No policy duplication in context or adapter files.
- Keep active files concise and current.
- Move stale or completed material to archive.

## 5) Tool Handling
- Optional tools must never appear as hard requirements.
- Fallback behavior must be defined inline where a tool is mentioned.
- Removing a tool must not break vault operation.
