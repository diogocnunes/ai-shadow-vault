# Laravel Superpowers Guide 🚀

This guide explains how to use the integrated **Laravel Superpowers** within your AI Shadow Vault workflow. These are specialized AI skills derived from the excellent [Laravel Superpowers](https://github.com/jpcaparas/superpowers-laravel) project.

## What are Superpowers?

Superpowers are **specialized instruction sets (Skills)** and **prompt templates (Commands)** designed to make your AI assistant an expert in specific Laravel domains.

Instead of generic advice, you get:
*   **TDD Workflows:** Strict Red-Green-Refactor cycles with Pest.
*   **Safe Migrations:** Patterns for zero-downtime database changes.
*   **Architecture:** Clean Code, Ports & Adapters, Service Layers.
*   **Sail Awareness:** Commands that automatically respect your Docker environment.

---

## 🛠️ Installation & Setup

### 1. Global Installation (Recommended)
To make these skills available to **Gemini CLI** (globally) and your **Code Editors** (Cursor, Windsurf):

```bash
# From the vault directory
./scripts/install_skills.sh
```
*   Select **Gemini CLI (Global)** to install them for terminal usage.
*   Select **Cursor/Windsurf** to append them to your project's rules files.
*   Choose "all" or select specific skills (e.g., `laravel:tdd-with-pest`, `laravel:migrations-and-factories`).

### 2. Project-Specific Initialization
To copy these skills into a specific project's documentation (useful for **Claude Code** context):

```bash
# Navigate to your Laravel project
cd ~/Sites/my-laravel-app

# Run the stack detector
vault-ai-init
# OR directly:
~/.ai-shadow-vault/scripts/auto_detect_stack.sh
```
This will automatically copy the relevant Markdown files into `.ai/docs/tech-stack/`, making them available as "Local Documentation" for any AI agent reading the `.ai` folder.

---

## 🤖 How to Use

### 1. Gemini CLI

The Gemini CLI uses the `activate_skill` tool. You don't need to remember the exact filename.

**Usage:**
Simply ask for the skill in natural language.

> **User:** "I need to design a new feature for Invoicing. Activate the **Laravel Brainstorming** skill."
>
> **Gemini:** *Calls `activate_skill('laravel:brainstorming')`...* "Okay, let's brainstorm. What is the goal of this feature?"

> **User:** "I'm fixing a bug in the User model. Use the **Debugging Prompts** skill."
>
> **Gemini:** *Calls `activate_skill('laravel:debugging-prompts')`...* "Please provide the error message and stack trace..."

**Manual Command Execution:**
If you prefer to use the raw prompt templates (Commands), they are automatically copied to your project's `.ai/commands/` folder during initialization.

> **User:** "Read `.ai/commands/brainstorm.md` and follow its instructions."

---

### 2. Claude Code (CLI)

Since Claude Code is context-aware, if you ran `vault-ai-init`, the skills are already in `.ai/docs/tech-stack/`.

**Usage:**
Reference the skill by name or concept.

> **User:** "Check the local docs for **TDD with Pest** and help me write a test for the `OrderService`."

> **User:** "I want to create a migration. Follow the **Migrations and Factories** guide in `.ai/docs`."

---

### 3. Cursor & Windsurf (Editors)

If you installed the skills via `install_skills.sh`, they are embedded in your `.cursorrules` or `.windsurfrules`.

**Usage:**
The editor's AI will automatically apply these rules when relevant.
*   When you ask to "Create a model", it will automatically suggest creating a Migration and Factory (per `migrations-and-factories` skill).
*   When you ask to "Refactor controller", it will follow the `controller-cleanup` guidelines automatically.

---

## ⚡ Top Skills Available

Here are some of the most powerful skills included:

| Skill | Description |
| :--- | :--- |
| **`laravel:brainstorming`** | Interactive design refinement. Clarifies domain, data, and interfaces before coding. |
| **`laravel:tdd-with-pest`** | Strict RED-GREEN-REFACTOR workflow using Pest PHP. |
| **`laravel:migrations-and-factories`** | Safe database change patterns. "Never edit a merged migration." |
| **`laravel:quality-checks`** | Unified quality gates: Pint, PHPStan, Tests. |
| **`laravel:controller-cleanup`** | Strategies to keep controllers thin (FormRequests, Actions). |
| **`laravel:debugging-prompts`** | Templates for reporting errors effectively to get better fixes. |
| **`laravel:filament-v5`** | Expert guidance for Filament V5 resources and forms. |

---

## ❤️ Credits

This integration is possible thanks to the open-source community.
*   **Original Project:** [Laravel Superpowers](https://github.com/jpcaparas/superpowers-laravel) by [JP Caparas](https://github.com/jpcaparas).
*   **Base Concept:** Superpowers for Claude by Jesse Vincent.
*   **License:** MIT.
