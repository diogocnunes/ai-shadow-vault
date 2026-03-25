<!-- AI-SHADOW-VAULT: MANAGED FILE -->

# Claude Adapter

Follow canonical authority from `AGENTS.md`.

- Keep this file adapter-only.
- Any tool mention must include fallback behavior inline.
- If optional tools are unavailable, continue with local vault sources.

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
10. Do not duplicate policy here; canonical policy is `.ai/rules.md`.
