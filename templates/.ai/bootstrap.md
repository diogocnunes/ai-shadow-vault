<!-- AI-SHADOW-VAULT: MANAGED FILE -->

# Bootstrap State
- Canonical policy: `.ai/rules.md`
- Primary enforcement surface: `CLAUDE.md`
- rules.md: <ok|missing>
- agent-context.md: <ok|missing>
- capabilities.json: <present|absent>
- last_check: <timestamp>
- last_result: <valid|invalid>
- remediation: `vault-bootstrap ensure`
- guard: `BOOTSTRAP_RUNNING=1` disables nested checks
