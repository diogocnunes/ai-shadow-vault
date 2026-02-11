# AI Cache System & Token Economy Guide 🛡️💰

The AI Cache System is an advanced expansion for the Shadow Vault designed to optimize AI interactions, reduce token costs, and maintain deep architectural context across sessions.

## 🚀 Core Workflow

1. **Initialize:** `vault-ai-init` (creates structure & symlinks)
2. **Resume:** `vault-ai-resume` (see what you were doing)
3. **Plan:** `.ai/agents/plan-creator.sh "New Feature"`
4. **Research:** `.ai/agents/doc-fetcher.sh "Library Name"`
5. **Code:** Use Claude, Gemini, or Cursor (context is automatically injected via `.ai/rules.md`)
6. **Save:** `vault-ai-save` (archive session & update stats)

## 📊 Operational Commands

| Command | Action | Purpose |
| :--- | :--- | :--- |
| `vault-ai-init` | Setup Structure | Initialize `.ai/` vault and project links |
| `vault-ai-save` | Archive Session | Moves `session.md` to archive, updates index & stats |
| `vault-ai-resume`| Restore Context | Shows last session recap and active plans |
| `vault-ai-stats` | Show Economy | Displays disk usage and estimated token savings |
| `cc` | Claude Start | Quick recap and clipboard context for Claude |

## 🤖 Sub-Agents (in `.ai/agents/`)

- `doc-fetcher.sh`: Local-first documentation search.
- `plan-creator.sh`: Standardized architectural planning.
- `context-update.sh`: Quick edit of the current session context.

## 🛡️ Git Safety & Privacy

The system automatically handles local and global git exclusions:
- `.ai/` and `.claude/` are added to `.gitignore`.
- Global protection is updated via `~/.gitignore_global`.

## 💰 Token Economy Strategy

- **Context Reuse:** By archiving sessions and using rules, you avoid re-sending the same architectural context every time.
- **Local Documentation:** Fetching local docs instead of asking the AI to "browse" or "explain" saves thousands of tokens per query.
- **Estimated Savings:** The `vault-ai-stats` command tracks your "Knowledge Bank" and calculates how many tokens you are NOT spending.
EOF
