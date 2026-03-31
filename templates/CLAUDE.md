<!-- AI-SHADOW-VAULT: MANAGED FILE -->

# Claude Adapter

## Instruction Priority
This file defines project-specific execution rules.
When more specific than `.ai/rules.md`, prefer this file.
Prefer native Claude tools when available; otherwise follow these rules for Bash-based execution.
If a conflict appears, do not ignore silently — report it.

---

## Mandatory Tools

### RTK — Bash Tool Commands Only
RTK is installed. These rules apply **only when using the Bash tool**.
Native Claude Code tools (`Read`, `Grep`, `Glob`, `Edit`) are always preferred over Bash.
When Bash is required:

| Operation | Use | Never use |
|-----------|-----|-----------|
| Git | `rtk git status`, `rtk git diff`, `rtk git log` | `git` directly in Bash |
| List | `rtk ls` | `ls` in Bash |
| Grep via shell | `rtk grep <pattern>` | `grep` / `rg` in Bash |
| Read via shell | `rtk read <path>` | `cat` / `head` in Bash |

No conflict with harness: harness says "use native tools when available" — RTK applies to the Bash fallback only.

### Gemini CLI — Large Context Analysis (Claude-invoked)
You (Claude) may invoke Gemini CLI as a tool when:
- Your analysis spans 3+ files simultaneously, or an entire directory
- You need a broad summary or cross-file pattern detection
- Estimated total content > 50KB

Do NOT invoke Gemini CLI for:
- Final decisions or answers requiring precision
- Complex debugging
- Anything where accuracy is critical

**Important**: Check `.ai/context/capabilities.json` for Gemini model constraints before use. If the capabilities file indicates a limited or free-tier model, treat Gemini output as directional only. Otherwise full usage is permitted. Always validate Gemini output locally using RTK or native Claude tools before acting.

```bash
gemini -p "@app/Services/ Summarize architecture and public methods"
gemini -p "@tests/Feature/ Audit test coverage gaps"
```

---

## Bootstrap Contract (Mandatory)
1. If `BOOTSTRAP_RUNNING=1`, skip bootstrap checks (recursion guard).
2. Verify `.ai/rules.md` exists and is readable.
3. Verify `.ai/context/agent-context.md` exists and is readable.
4. If `.ai/context/capabilities.json` exists, load it before tool selection.
5. Output: `BOOTSTRAP_ACK: rules+context loaded` before task execution.
6. If any required check fails: STOP and REPORT (no execution).
7. Show warning block with failed checks and remediation command.
8. Remediation command: `vault-bootstrap ensure`.
9. BOOTSTRAP_ACK is an audit signal only (not a guarantee of compliance).
