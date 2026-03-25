# Versioning Policy (Migration)

- Deprecations may be introduced in minor releases.
- Removals happen only in major releases.
- Legacy fallback windows must remain active for at least 90 days before removal.
- Pack compatibility uses `core_api` from `pack.json` and is enforced by `vault-ext enable` and `vault-ext sync`.
