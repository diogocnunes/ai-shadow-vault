# AI Shadow Vault v3.1.4

## Summary

This release reduces active context noise by archiving completed plans during `vault-ai-save`, while preserving plan history under the archive directory.

## What's New

- `vault-ai-save` now scans `.ai/plans/*.md` and archives completed plans automatically.
- Completed plans are moved to `.ai/context/archive/plans/` instead of being deleted.
- Completion detection is flexible and case-insensitive, based on `Status:` values containing:
  - `Completed`
  - `Concluído`
  - `Done`
- Filename collision handling was added for archived plans by appending timestamp-based suffixes.
- Save output now includes a summary of archived completed plans.

## Documentation Updates

- Updated `README.md` command reference for `vault-ai-save`.
- Updated `README_PT.md` command reference for `vault-ai-save`.

## Notes

- Active plan views remain clean because archived plans leave `.ai/plans/`.
- Historical traceability is preserved in `.ai/context/archive/plans/`.
