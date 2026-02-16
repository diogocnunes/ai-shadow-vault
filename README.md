# AI Shadow Vault 🛡️

**AI Shadow Vault: A local DX infrastructure for context-aware AI coding. It uses ZSH-automated symlinks to inject private context and rules from a secure vault into your workflow. Eliminate git pollution and privacy leaks while optimizing AI performance and costs. The elite setup for professional, private, and efficient AI-driven development.**

---

## 🚀 The Concept
This project solves the "Context Dilemma": How to give AI deep project knowledge without committing sensitive `.md` files to your team's repository or polluting your `.gitignore`.

By using a decentralized **Vault** in your `$HOME` directory and ZSH hooks, this tool automatically injects context via symbolic links whenever you enter a project folder. It now provides **Universal AI Support**, seamlessly integrating with **Gemini, Claude, Cursor, Windsurf, GitHub Copilot, and Cody/Junie**.

## 🛠️ Installation

1. **Clone & Setup:**
   ```bash
   git clone https://github.com/diogocnunes/ai-shadow-vault.git ~/.ai-shadow-vault
   mkdir -p ~/.gemini-vault
   ```

2. **ZSH Integration:** Add this line to your `~/.zshrc`:
    ```bash
    source ~/.ai-shadow-vault/scripts/shell_integration.zsh
    ```

3. **Initialize a Project:**
   Navigate to your project folder and simply run:
   ```bash
   vault-init
   ```

## 🤖 Multi-AI Strategy (How it works)

The Vault maps specific files to the expected standards of each AI tool. When you enter a directory, the shell script creates the following symlinks:

| File in Vault | Symlink Target | Primary AI / Tool |
| :--- | :--- | :--- |
| `GEMINI.md` | `./GEMINI.md` | Google Gemini |
| `CLAUDE.md` | `./CLAUDE.md` | Anthropic Claude |
| `AGENTS.md` | `./AGENTS.md` | Custom AI Agents |
| `.cursorrules` | `./.cursorrules` | **Cursor Editor** |
| `.windsurfrules` | `./.windsurfrules` | **Windsurf (Codeium)** |
| `copilot-instructions.md` | `./.github/copilot-instructions.md` | **GitHub Copilot** |
| `cody-context.json` | `./.cody/context.json` | **Cody / Junie** |
| `cody-ignore` | `./.cody/ignore` | **Cody / Junie** |
| opencode.json | `./.opencode.json` | OpenCode Engine |

> **Note:** For tools like GitHub Copilot and Cody, the tool automatically manages the necessary subdirectories (`./.github/` or `./.cody/`) for you.

## ⚡ Dynamic Skills Integration (New!)

Beyond basic project context, the Shadow Vault now supports **Dynamic Skills**. These are specialized sets of instructions that can be injected into any of your AI assistants to provide them with expert-level knowledge on specific domains.

### The `vault-skills` Command
Run `vault-skills` in any project directory to:
1. **Choose your AIs:** Select which assistants you want to empower (Gemini CLI, Cursor, Windsurf, Copilot, or Claude).
2. **Choose the Skills:** Select from a marketplace of expert profiles:
    - **Backend Expert:** PHP 8.3, Laravel 11, Nova 5, Eloquent optimization.
    - **Frontend Expert:** Vue 3 Composition API, PrimeVue, backoffice UX.
    - **QA Automation:** Pest PHP, Playwright, testing strategies.
    - **Architect Lead:** System design, migration strategies, patterns.
    - **DX Maintainer:** Linting, CI/CD, code quality (Pint, PHPStan).
    - **Legacy Migration Specialist:** Safe upgrades for legacy stacks.
    - **Security & Performance:** Hardening and optimization patterns.

### How it handles different AIs:
- **Gemini CLI:** Installs the skill globally in `~/.gemini/skills/` so it's always available via `activate_skill`.
- **Editors (Cursor, Windsurf, etc.):** Appends the skill instructions directly to your local rules file (e.g., `.cursorrules`) in the current project, automatically stripping unnecessary metadata and ensuring the AI follows the specific domain guidelines.

---

## 🚀 Laravel Boost Support
When running `vault-init` on a Laravel project, the script automatically detects it by checking for `composer.json` and the Laravel framework dependency. This feature was contributed by **@cristianovalenca**.

If a Laravel project is detected, you'll be prompted to install **Laravel Boost**, a powerful tool that enhances AI-assisted development in Laravel applications.

**What happens when you choose to install:**
1. Runs `composer require laravel/boost --dev`
2. Executes `php artisan boost:install` to configure Laravel Boost
3. Automatically adds Laravel Boost files to your global `.gitignore`

**Protected Laravel Boost files:**
- `.mcp.json` - MCP server configuration
- `CLAUDE.md` - AI guidelines for Claude (Universal support added by **@maclevison**)
- `boost.json` - Boost configuration
- `.ai/` - Custom guidelines directory

Just like the Shadow Vault files, these are automatically excluded from Git to keep your repository clean while maintaining full AI context capabilities.

## 🛡️ Safety First: Global Git Protection
The `vault-init.sh` script automatically configures a global git exclusion ruleset. It ensures that your private AI instructions **never** leak into production or team commits. It updates your `~/.gitignore_global` to include:
- `GEMINI.md`
- `AGENTS.md`
- `.opencode.json`
- `.mcp.json`
- `CLAUDE.md`
- `boost.json`
- `.ai/`
- `copilot-instructions.md`
- `.cursorrules`
- `.windsurfrules`
- `cody-context.json`
- `cody-ignore`
- `.github/`
- `.cody/`
- `.claude/`
- `.codex/`
- `.cursor/`
- `.gemini/`
- `.junie/`
- `.opencode/`

This ensures that even if a symlink is created locally, it will **never** be detected, staged, or committed by Git, keeping your AI instructions private and your repository clean.

## 💰 Cost Optimization (Gemini Flash + Paid Tier)

To maximize performance while keeping costs near zero, this setup prioritizes the **Gemini Flash** model for operational tasks (Build/Plan) and reserves **Gemini Pro** for complex architectural decisions.

### How to configure "Safety Brakes":

1. **Enable Paid Tier (Level 1):** Go to [Google AI Studio](https://aistudio.google.com/) and switch your plan to **Pay-as-you-go**. This removes the "Free Tier" rate limits (20 requests/min), enabling smooth `/init` commands without interruptions.

2. **Set Hard Quotas (The "Kill Switch"):** In the [Google Cloud Console](https://console.cloud.google.com/apis/api/generativelanguage.googleapis.com/quotas), edit your **"Paid Tier"** quotas to prevent unexpected costs:
   - **Gemini Flash:** Set to **500** requests per day.
   - **Gemini Pro:** Set to **200** requests per day.
   - These limits ensure that even in a "loop" scenario, you won't spend more than a few cents per day.

3. **Budget Alerts:** Set a monthly budget alert of **$5.00** in Google Cloud Billing to receive immediate email notifications of any spending.

## 🚀 Laravel Superpowers Integration (New in 1.6.0)

We have integrated the **[Laravel Superpowers](https://github.com/jpcaparas/superpowers-laravel)** collection directly into the Vault. This gives your AI agents 50+ specialized skills for Laravel development, ranging from TDD workflows to advanced architecture patterns.

**Features:**
*   **Auto-Detection:** The `vault-ai-init` script now detects if you are running **Laravel Sail** and adjusts all command instructions accordingly.
*   **Skill Injection:** Automatically copies relevant Superpowers (like `laravel:tdd-with-pest`, `laravel:migrations-and-factories`) into your project's `.ai/docs/` folder.
*   **Universal Access:** Use these skills in **Gemini CLI** (via `activate_skill`), **Claude Code**, or **Cursor/Windsurf**.

👉 **[Read the Full Superpowers Guide](./SUPERPOWERS_GUIDE.md)**

## ❤️ Credits & Inspiration

The Shadow Vault evolves thanks to the community. Special thanks to:
*   **[JP Caparas](https://github.com/jpcaparas)** for the **[Laravel Superpowers](https://github.com/jpcaparas/superpowers-laravel)** project, which inspired our new skill system.
*   **@cristianovalenca** for the initial Laravel detection logic.
*   **@maclevison** for the Universal Claude support.

## 📊 Monitoring
Run `vault-check` at any time to verify the integrity of your symlinks and the status of your context files across all projects in the Vault.

### Example Output:
```text
🔍 Starting AI Shadow Vault Health Check...
------------------------------------------
📁 Project: my-laravel-app
  ✅ AGENTS.md (OK) (1.2K)
  ✅ GEMINI.md (800B)
  ✅ Copilot Instructions (1.5K)
  ℹ️  opencode.json (Using Global Config)

📁 Project: react-dashboard
  ✅ AGENTS.md (OK) (2.1K)
  ⚠️  GEMINI.md (Empty - Run vault-init soon)
  ✅ Copilot Instructions (900B)
------------------------------------------
✨ Vault Scan Complete.
```

## 🛡️ AI Cache System & Token Economy (New!)

The Shadow Vault now includes a sophisticated **AI Cache System** designed to minimize token usage and maintain architectural consistency across long sessions. It works by creating a persistent knowledge bank in your vault that is symlinked to your project's `.ai/` directory.

### 🚀 Key Features:
- **Persistent Sessions:** Archive your thoughts and goals with `vault-ai-save`.
- **Architectural Rules:** Enforce project-wide standards (Laravel 11, PHP 8.3, etc.) via `.ai/rules.md`.
- **Token Savings:** Track how many tokens you save by reusing local context and documentation.
- **Claude Integration:** Optimized workflow for Claude Code with local rules and context recap.

### 🛠️ Operational Commands:

| Command | Action | Description |
| :--- | :--- | :--- |
| `vault-ai-init` | Initialize | Setup the expanded `.ai/` structure |
| `vault-ai-save` | Save & Archive | Persists the current session and updates the index |
| `vault-ai-resume` | Resume Context | Shows a recap of where you left off |
| `vault-ai-stats` | Show Stats | Calculates disk usage and token economy |
| `cc` (Alias) | Claude Start | Prepares context for a new Claude Code session |

## 🧠 Dynamic Context & Stack Detection (V1.5.1)

The Shadow Vault is no longer static. It now features an **Intelligent Configurator** that acts as an **AI Onboarding Assistant**, analyzing your project's DNA to tailor the AI's instructions.

### 🔍 How it Works:
When you run `vault-init` or `vault-ai-init`, the system:
1. **Analyzes Dependencies:** Scans `composer.json` and `package.json`.
2. **Detects Tech Stack:**
    - **Backend:** PHP version, Laravel version.
    - **Admin Panels:** Automatically distinguishes between **Filament** and **Laravel Nova**.
    - **Frontend:** Identifies **Vue.js**, **React**, or **Livewire (TALL Stack)**.
    - **UI Libraries:** Detects **Quasar**, **PrimeVue**, or **TailwindCSS**.
3. **Interactive Briefing (New!):**
    - **Environment:** Select between **Laravel Herd, Sail, Valet, Docker, or Laradock**.
    - **Database:** Define your DB engine (**MySQL, PostgreSQL, MariaDB, etc.**).
    - **Business Context:** Input your project's **Goal** and **Key Integrations** (Stripe, AWS, etc.) during setup.
4. **Generates Tailored Rules:** Dynamically populates `rules.md`, `GEMINI.md`, and `CLAUDE.md` with project-specific commands and architecture notes.

### 🤖 AI Orchestration:
All generated files now include **Cross-AI Orchestration Rules**. This ensures that Gemini and Claude:
- **Prioritize the Vault:** Always look into `.ai/` first.
- **Bypass Git Ignores:** Automatically use `cat` or shell commands to read files that are symlinked or hidden from Git.
- **Stay in Scope:** Use the correct testing (Pest/PHPUnit) and build (Vite/Mix) tools detected during init.

### 🤖 Local AI Agents:
Located in `.ai/agents/`, these scripts automate routine tasks:
- `plan-creator.sh`: Creates standardized architectural plans.
- `doc-fetcher.sh`: Searches local docs before going online.
- `context-update.sh`: Quick edit of the current session goals.

For more details, check the [AI Cache Guide](./AI_CACHE_GUIDE.md).

💻 System Compatibility
