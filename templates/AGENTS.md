# AGENTIC CODING GUIDELINES

## Core Principles
- **SOLID & DRY:** Mandatory adherence to clean code principles.
- **Strict Typing:** Use `declare(strict_types=1);` and native PHP 8.3+ type hints.
- **Service-Action Pattern:** Business logic stays in Services/Actions, not Controllers/Models.

## Tools & Standards
- **Testing:** New features require PestPHP tests. Use `Http::fake()` for external APIs.
- **Linting:** Run `./vendor/bin/pint` before finalizing any code.
- **Frontend:** Use Vue 3 Composition API (`<script setup>`) and TailwindCSS.
- **Laravel Superpowers:** You have access to specialized Laravel skills (TDD, Migrations, Clean Controllers, etc.). Use `activate_skill` when relevant.

## AI Interaction Rules
- Consult `GEMINI.md` for project architecture.
- Follow `AGENTS.md` for coding style and patterns.