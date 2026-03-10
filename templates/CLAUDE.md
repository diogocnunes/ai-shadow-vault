# {Project Name} - Claude AI Guidelines

## Context Priority

Use this order when gathering context:

1. `.ai/plans/`
2. `.ai/skills/ACTIVE_SKILLS.md`
3. `.ai/rules.md`
4. `.ai/context/agent-context.md`
5. `.ai/docs/`

## Shadow Vault Rules

- The `.ai/` directory is the project's local context layer.
- If Git ignore rules hide files, read them explicitly instead of assuming they do not exist.
- Treat `CLAUDE.md` as orchestration guidance, not as the place to accumulate appended raw skills forever.

## Working Style

- Prefer focused changes tied to an explicit plan.
- Reuse existing patterns before introducing new abstractions.
- Keep recommendations aligned with the active skills bundle when present.
