# Laravel Superpowers Guide

Este guia cobre a integração de skills Laravel dentro do AI Shadow Vault.

## O que este guia cobre

O foco aqui é:

- skills Laravel reutilizáveis
- docs locais em `.ai/docs/tech-stack/`
- sincronização dessas skills entre agentes

## Como as skills chegam aos agentes

### Gemini

Instalação nativa em:

```text
~/.gemini/skills/<skill>/SKILL.md
```

### Codex

Instalação nativa em:

```text
~/.codex/skills/<skill>/SKILL.md
```

### Claude, Junie e Opencode

Uso principal via:

```text
.ai/skills/ACTIVE_SKILLS.md
```

### Cursor, Windsurf e Copilot

Uso através de regras locais regeneradas pelo `vault-skills sync`.

## Fluxo recomendado para Laravel

```bash
vault-init
vault-ai-init
vault-skills activate --preset laravel-nova
vault-skills sync native context
```

## Casos típicos

### Projeto Laravel + Nova

```bash
vault-skills activate --preset laravel-nova
vault-skills sync native context
```

### Projeto Laravel + Filament

```bash
vault-skills activate --preset filament
vault-skills sync native context
```

### Projeto TALL Stack

```bash
vault-skills activate --preset tall-stack
vault-skills sync native context
```

## Skills vs docs locais

Use skills para comportamento e prioridades.

Exemplos:

- arquitetura
- code quality
- QA
- segurança
- migração legada

Use docs locais para detalhe técnico concreto.

Exemplos:

- padrões Nova
- eager loading
- validação
- Pest
- Filament

## Upgrade de projetos antigos

Se o projeto acumulou skills antigas em `CLAUDE.md`, `.cursorrules` ou ficheiros semelhantes:

```bash
vault-skills standardize
```

O comando cria backups antes de reescrever os ficheiros geridos.

## Créditos

Esta integração é inspirada no projeto [Laravel Superpowers](https://github.com/jpcaparas/superpowers-laravel) de [JP Caparas](https://github.com/jpcaparas).
