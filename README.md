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

💻 System Compatibility
