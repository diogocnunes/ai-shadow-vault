# AI Shadow Vault v3.1.3

## Summary

This release adds an opt-in Gemini CLI guidance section for large codebase analysis, with managed section support across instruction surfaces and safe behavior by default.

## What's New

- Added `vault-init --use-gemini` to enable a managed `gemini-large-context` section.
- Added `vault-init --no-use-gemini` to remove that managed section.
- Added runtime Gemini CLI presence checks before enabling the section.
- Added non-destructive default mode (`preserve`) so existing projects are not force-changed.
- Extended `vault-skills sync` compatibility so managed Gemini guidance is preserved across target rewrites.

## Documentation Updates

- Updated `README.md` and `README_PT.md` with the new `vault-init` flags.
- Updated `GEMINI_WORKFLOW_GUIDE.md` with optional Gemini large-context workflow usage and compatibility note.
- Updated `templates/CLAUDE_PROJECT_RULES.md` with query-priority guidance when Gemini large-context mode is enabled.

## Notes

- The managed Gemini section includes a compatibility note to validate local CLI flags (for example, `gemini --help`) before relying on command variants like `--all_files`.
- Guidance remains aligned with existing local-first context rules and RTK verification flow.
