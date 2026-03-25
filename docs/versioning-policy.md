# Versioning Policy (Migration)

- Deprecations may be introduced in minor releases.
- Removals happen only in major releases.
- Legacy fallback windows must remain active for at least 90 days before removal.
- Pack compatibility uses `core_api` from `pack.json` and is enforced by `vault-ext enable` and `vault-ext sync`.

Current Laravel soft migration window:

- Started: 2026-03-25
- Legacy fallback guaranteed until: 2026-06-23
- Hard removal target: 3.0.0 (next major)
