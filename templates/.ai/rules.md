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

## 6) Capability Usage (When Available)
- Read `.ai/context/capabilities.json` before selecting tooling.
- If `rtk.available` is `1`, use RTK wrappers by default whenever an equivalent exists.
- If `gemini_cli.available` is `1`, use Gemini CLI for large-context or cross-file analysis.
- If `context7.available` is `1`, use Context7/MCP for external library or API facts before making assumptions.
- If any capability is unavailable, continue with native/local fallback and do not block execution.

## 7) Git & Commit Safety

**Read-only git operations** (may run autonomously):
- `git status`, `git diff`, `git log` — safe to run without approval.

**Operations that require explicit user approval before running:**
- `git commit`, `git add`, `git push`, `git merge`, `git rebase`, `git reset`,
  `git checkout` (branch switches), `git stash` — always present the proposed
  action and wait for confirmation.
- Never push to any remote branch unless the user explicitly requests it.
- Never force-push (`--force`, `--force-with-lease`) to `main`/`master` under
  any circumstance.
- This applies to all contexts: main conversation, subagents, and plan executors,
  including when running in `--dangerously-skip-permissions` mode.

**Secrets and sensitive data:**
- NEVER commit `.env` files, API keys, passwords, tokens, database dumps,
  credential files, or private key files.
- Before committing, verify staged files contain no sensitive data.
- If a staged file contains sensitive data, refuse to commit and warn the user.

**Scope and cleanup:**
- Prefer small, focused commits; avoid bundling unrelated changes.
- Before finishing any task, delete helper-generated artifacts that must not be
  committed: `storage/pest-junit.xml`, Playwright reports and traces
  (`playwright-report/`, `test-results/`, `*.trace.zip`), and any other
  tool-output files not tracked in `.gitignore`.
