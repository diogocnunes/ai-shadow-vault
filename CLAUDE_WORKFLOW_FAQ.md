# Claude Workflow Guide

Este guia descreve o fluxo recomendado para usar o AI Shadow Vault com Claude Code.

## Entrada rápida: `cc`

O comando `cc`:

1. mostra o resumo da última sessão
2. mostra os planos ativos
3. copia `.ai/rules.md` para a área de transferência, quando possível
4. regenera `.ai/context/agent-context.md`

## Fontes de contexto para Claude

Claude deve priorizar:

1. `.ai/plans/`
2. `.ai/skills/ACTIVE_SKILLS.md`
3. `.ai/rules.md`
4. `.ai/context/agent-context.md`
5. `.ai/docs/`

## Fluxo recomendado

```bash
cc
.ai/agents/plan-creator.sh "Corrigir fluxo de autenticação"
vault-skills activate --preset laravel-nova
vault-skills sync claude
claude
vault-ai-save
```

## Exemplo de prompt

```text
Leia .ai/skills/ACTIVE_SKILLS.md e .ai/context/agent-context.md.
Depois siga .ai/plans/corrigir-fluxo-de-autenticacao.md.
Investigue apenas os ficheiros necessários.
```

## `ACTIVE_SKILLS.md` vs `agent-context.md`

Use `.ai/skills/ACTIVE_SKILLS.md` para comportamento especializado.

Use `.ai/context/agent-context.md` para resumo da sessão atual.

Use ambos quando a task tiver contexto de negócio e também requisitos técnicos específicos.

## Plano físico vs `/plan`

- `.ai/agents/plan-creator.sh`: cria um plano persistente
- `/plan` do Claude: ajuda no raciocínio da execução atual

Regra prática:

- primeiro defina a estratégia no ficheiro do plano
- depois peça ao Claude para executar com base nele

## Projetos antigos

Se `CLAUDE.md` e ficheiros relacionados estiverem desorganizados por skills antigas:

```bash
vault-skills standardize
```
