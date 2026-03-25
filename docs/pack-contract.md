# Pack Contract (MVP)

AI Shadow Vault pack manifests use `pack.json` at pack repository root.

Required fields:

- `name`: unique pack package name
- `version`: pack semver
- `description`: short human description
- `core_api`: supported core semver range
- `capabilities`: non-empty array of capability strings

Example:

```json
{
  "name": "ai-shadow-vault-laravel",
  "version": "1.0.0",
  "description": "Official Laravel skill pack for AI Shadow Vault",
  "core_api": ">=2.1.0 <3.0.0",
  "capabilities": ["skills"]
}
```

Validation command:

```bash
vault-pack validate /path/to/pack
```
