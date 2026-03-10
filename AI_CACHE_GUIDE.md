# AI Cache Guide

Este guia explica a camada local `.ai/` do AI Shadow Vault.

## Objetivo

A pasta `.ai/` existe para reduzir contexto repetido entre sessões e entre agentes.

Ela concentra:

- regras do projeto
- planos persistentes
- documentação local
- histórico arquivado
- contexto portátil
- bundle de skills ativas

## Estrutura principal

| Caminho | Função |
| :--- | :--- |
| `.ai/rules.md` | regras globais do projeto |
| `.ai/plans/` | planos de implementação |
| `.ai/docs/` | documentação local |
| `.ai/context/archive/` | sessões arquivadas |
| `.ai/context/agent-context.md` | resumo portátil da sessão |
| `.ai/skills/ACTIVE_SKILLS.md` | bundle das skills ativas |

## Inicialização

No projeto:

```bash
vault-ai-init
```

## Fluxo básico

```bash
vault-ai-resume
.ai/agents/plan-creator.sh "Melhorar dashboard"
vault-ai-context
vault-ai-save
```

## O papel do `agent-context.md`

`.ai/context/agent-context.md` serve para:

- Superset
- Polyscope
- agentes sem clipboard
- prompts que precisam de um único ficheiro de contexto

Exemplo de prompt:

```text
Leia .ai/context/agent-context.md como resumo atual do projeto.
Depois siga .ai/plans/melhorar-dashboard.md.
```

## O papel do `ACTIVE_SKILLS.md`

`.ai/skills/ACTIVE_SKILLS.md` agrega as skills ativas para agentes orientados a ficheiros.

Use-o quando:

- a ferramenta não tem sistema nativo de skills
- quer partilhar o mesmo conjunto de skills entre Claude, Junie e Opencode
- quer um fallback portátil mesmo para Gemini e Codex

Exemplo:

```text
Use .ai/skills/ACTIVE_SKILLS.md como bundle de skills ativo antes de propor arquitetura, testes ou refactors.
```

## Continuidade de sessão

O ciclo esperado é:

1. notas ativas em `.ai/session.md`
2. `vault-ai-save` arquiva a sessão
3. `vault-ai-resume` mostra o último estado
4. `vault-ai-context` regenera o contexto portátil

## Boas práticas

- mantenha `.ai/rules.md` curto e reutilizável
- coloque conteúdo longo em `.ai/docs/`
- use `.ai/plans/` para estratégia
- use `agent-context.md` para transporte de contexto
- use `vault-skills standardize` para normalizar projetos antigos
