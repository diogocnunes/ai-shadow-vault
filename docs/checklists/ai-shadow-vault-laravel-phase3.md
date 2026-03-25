# Checklist - AI Shadow Vault Laravel Pack (Phase 3)

Use this checklist in `~/Sites/MySites/ai-shadow-vault-laravel`.

## 1) Repository Baseline

- [ ] Repository exists and is accessible.
- [ ] Default branch is `main`.
- [ ] License and README are present.

## 2) Required Files

- [ ] `pack.json` exists at repository root.
- [ ] `pack.json` contains required fields:
  - [ ] `name`
  - [ ] `version`
  - [ ] `description`
  - [ ] `core_api`
  - [ ] `capabilities`
- [ ] `skills/` exists and includes initial Laravel skill files.

Example `pack.json`:

```json
{
  "name": "ai-shadow-vault-laravel",
  "version": "1.0.0",
  "description": "Official Laravel skill pack",
  "core_api": ">=2.1.0 <3.0.0",
  "capabilities": ["skills"]
}
```

## 3) Pack Source of Truth

After hard migration, Laravel skills are owned directly in the pack repository:

- [ ] `ai-shadow-vault-laravel/skills/` is the source of truth.
- [ ] No extraction from core is required.

## 4) Contract Validation

From core repo:

```bash
bin/vault-pack validate ~/Sites/MySites/ai-shadow-vault-laravel
```

- [ ] Validation passes.

## 5) Local Integration Smoke Test

In a test project:

```bash
CORE=~/Sites/MySites/ai-shadow-vault

"$CORE/bin/vault-ext" disable laravel || true
"$CORE/bin/vault-ext" enable laravel
"$CORE/bin/vault-ext" sync
cat .ai/extensions/lock.json

"$CORE/bin/vault-ext" enable skills
"$CORE/bin/vault-skills" set backend-expert
cat .ai/skills/ACTIVE_SKILLS.md
```

- [ ] `lock.json` includes pack `laravel`.
- [ ] Active skills resolve from pack path under `.ai-shadow-vault-data/packs/...`.

## 6) Release Preparation

- [ ] Commit pack contents.
- [ ] Tag initial release (`v1.0.0`).
- [ ] Push branch and tag.
- [ ] Confirm core extension points to desired ref (`DEFAULT_REF=v1.0.0`).

## 7) Post-Release Checks

- [ ] `vault-ext enable laravel` works on clean project.
- [ ] `vault-ext enable laravel-stack` maps to `laravel` (legacy compatibility).
- [ ] Hard-cut behavior confirmed: mapped Laravel skills require pack (`ASV-HARD-MIGRATION-001` when pack is not enabled).
