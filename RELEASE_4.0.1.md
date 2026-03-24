# AI Shadow Vault v4.0.1

## Summary

This release adds a natural-language Task Prompt Compiler to `vault-task`, including Portuguese authoring support, structured task generation, and a dedicated validation section in the canonical task format.

## What's New

- Added `vault-task compile` to convert natural-language engineering requests into execution-ready structured tasks.
- Added bilingual parsing support (Portuguese + English), including mixed-language input handling.
- Added extraction and preservation of explicit references (`@app/...`, `@lang/...`, URLs) during compilation.
- Added output controls:
  - `--output-lang en|pt|auto`
  - `--enrich conservative|repo-aware`
  - `--format markdown|json`
  - `--apply` for explicit write to `.ai/context/current-task.md`
- Added heuristic task-type enrichment (for example UI/i18n/tests) with compiler diagnostics when data is inferred.

## Schema Updates

- Added `## Validation Instructions` to the canonical task structure.
- Updated `vault-task new`, `vault-task quick`, template fallback, and save/reset flows to include this section consistently.

## Documentation Updates

- Updated `README.md` with `vault-task compile` command surface and behavior.
- Updated `README_PT.md` with PT/EN compile usage and preview/apply flow.

## Quality & Validation

- Extended `vault-test` task suite to validate compiler flow, archive behavior, and preservation of explicit `@...` references.
- Verified full test suite with `vault-test --all`.
