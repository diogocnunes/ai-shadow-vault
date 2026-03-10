# {{PROJECT_NAME}} - Claude AI Guidelines

## Context Priority

Use this order when gathering context:

1. `.ai/plans/`
2. `.ai/skills/ACTIVE_SKILLS.md`
3. `.ai/rules.md`
4. `.ai/context/agent-context.md`
5. `.ai/docs/`

## Shadow Vault Rules

- The `.ai/` directory contains the project's active context and should be prioritized.
- If Git ignore rules hide files, read them explicitly rather than assuming they are unavailable.
- Treat `CLAUDE.md` as orchestration guidance, not as a dump for appended skills.

## Project Context

- Goal: {{PROJECT_CONTEXT}}
- Integrations: {{KEY_INTEGRATIONS}}
- Stack: {{FRAMEWORK}} {{FRAMEWORK_VERSION}} / {{FRONTEND_STACK}} / {{ADMIN_PANEL}}
- Environment: {{DEV_ENVIRONMENT}}
- Language: {{PRIMARY_LANGUAGE}}
- Formatting: {{FORMATTING_TOOLS}}
- Build: {{BUILD_COMMAND}}
- Dev: {{DEV_COMMAND}}
- Test: {{TEST_COMMAND}}
