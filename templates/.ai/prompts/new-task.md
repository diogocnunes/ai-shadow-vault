<!-- AI-SHADOW-VAULT: MANAGED FILE -->

# /new-task (Portable)

If the active agent supports slash commands, install this as `/new-task`.
If slash commands are unavailable, use this file directly.

Create or replace `.ai/context/current-task.md` with exactly:

---
mode: plan|execute
---

## Goal
<clear desired outcome>

## Context
<facts needed to execute safely>

## Constraints
<scope limits, non-goals, hard requirements>

## Success Criteria
- <measurable check 1>
- <measurable check 2>

## Private Deliverables (Optional)
- <private artifact/path or "none">

Vault operation must not depend on slash-command support.
