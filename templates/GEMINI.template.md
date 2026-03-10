# {{PROJECT_NAME}} Overview

## Context Priority

Use this order when gathering context:

1. `.ai/plans/`
2. native Gemini skills if activated
3. `.ai/skills/ACTIVE_SKILLS.md`
4. `.ai/rules.md`
5. `.ai/context/agent-context.md`
6. `.ai/docs/`

## Tech Stack
- Backend: {{FRAMEWORK}} {{FRAMEWORK_VERSION}} / PHP {{PHP_VERSION}}
- Frontend: {{FRONTEND_STACK}} {{FRONTEND_VERSION}} / {{UI_LIBRARY}}
- Database: {{DATABASE_STACK}}
- Environment: {{DEV_ENVIRONMENT}}
- Admin: {{ADMIN_PANEL}} {{ADMIN_VERSION}}

## Shadow Vault Rules

- The `.ai/` directory contains the project's critical context, plans, and history.
- Read `.ai/` even when Git ignore rules would normally hide it.
- Treat native Gemini skills and `.ai/skills/ACTIVE_SKILLS.md` as complementary sources.

## Context
{{PROJECT_CONTEXT}}
