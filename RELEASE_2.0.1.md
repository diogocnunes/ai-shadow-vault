# AI Shadow Vault 2.0.1

## Summary

This release adds built-in user-stories planning support to AI Shadow Vault.

## Highlights

- Added a built-in `user-stories` skill for codebase analysis and story breakdown.
- Added `vault-user-stories` to prepare a planning prompt and target output path inside `.ai/plans/`.
- Added `vault-breakdown` as an alias for the same workflow.
- Added the `planning` preset to activate `user-stories` quickly.
- Added a project-local `.ai/agents/user-stories.sh` helper for initialized projects.
- Updated English and Portuguese documentation with the new planning workflow.

## User-facing commands

```bash
vault-user-stories "Implement OAuth login"
vault-breakdown "Implement OAuth login"
vault-skills activate --preset planning
```

## Notes

- Generated plans are expected at `.ai/plans/<slug>.user-stories.md`.
- `vault-user-stories` refreshes `.ai/context/agent-context.md` before preparing the prompt.
- Clipboard failures now fall back cleanly to manual copy.
