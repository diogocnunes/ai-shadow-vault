# AI Shadow Vault 🛡️

**AI Shadow Vault: A local DX infrastructure for context-aware AI coding. It uses ZSH-automated symlinks to inject private context and rules from a secure vault into your workflow. Eliminate git pollution and privacy leaks while optimizing AI performance and costs. The elite setup for professional, private, and efficient AI-driven development.**

---

## 🚀 The Concept
This project solves the "Context Dilemma": How to give AI deep project knowledge without committing sensitive `.md` files to your team's repository or polluting your `.gitignore`.

By using a decentralized **Vault** in your `$HOME` directory and ZSH hooks, this tool automatically injects context via symbolic links whenever you enter a project folder. It now supports **Gemini, OpenCode, Claude, and GitHub Copilot** seamlessly.

## 🛠️ Installation

1. **Clone & Setup:**
   ```bash
   git clone [https://github.com/diogocnunes/ai-shadow-vault.git](https://github.com/diogocnunes/ai-shadow-vault.git) ~/.ai-shadow-vault
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
| `GEMINI.md` | `./GEMINI.md` | Google Gemini / gemini-cli |
| `AGENTS.md` | `./AGENTS.md` | Claude / OpenCode / Custom Agents |
| `copilot-instructions.md` | `./.github/copilot-instructions.md` | **GitHub Copilot** |
| `opencode.json` | `./.opencode.json` | OpenCode Engine |

> **Note:** For GitHub Copilot, the tool automatically manages the `./.github/` directory for you, ensuring the instructions are placed exactly where the Copilot engine looks for them.

## 🛡️ Safety First: Global Git Protection
The `vault-init.sh` script automatically configures a global git exclusion ruleset. It ensures that your private AI instructions **never** leak into production or team commits. It updates your `~/.gitignore_global` to include:
- `GEMINI.md`
- `AGENTS.md`
- `.opencode.json`
- `copilot-instructions.md`

This ensures that even if a symlink is created locally, it will **never** be detected, staged, or committed by Git, keeping your AI instructions private and your repository clean.

## 💰 Cost Optimization (Gemini Flash + Paid Tier)

To maximize performance while keeping costs near zero, this setup prioritizes the **Gemini Flash** model for operational tasks (Build/Plan) and reserves **Gemini Pro** for complex architectural decisions.

1. **Enable Paid Tier:** Switch to **Pay-as-you-go** in [Google AI Studio](https://aistudio.google.com/) to remove rate limits.
2. **Set Hard Quotas:** In the Google Cloud Console, limit Flash to ~500 requests/day and Pro to ~200 requests/day to prevent surprises.
3. **Budget Alerts:** Set a **$5.00** monthly alert to receive immediate notifications of any spending.

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
