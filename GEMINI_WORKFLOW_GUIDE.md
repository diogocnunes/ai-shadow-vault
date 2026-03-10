# Gemini Workflow Guide

Este guia descreve o uso do AI Shadow Vault com Gemini.

## Onde o Gemini ajuda mais

Gemini é especialmente útil para:

- investigação estrutural
- validação de arquitetura
- exploração mais ampla do código
- revisão de coerência entre plano e implementação

## Fontes de contexto para Gemini

Gemini deve priorizar:

1. `.ai/plans/`
2. skills nativas do Gemini, quando ativadas
3. `.ai/skills/ACTIVE_SKILLS.md`
4. `.ai/rules.md`
5. `.ai/context/agent-context.md`
6. `.ai/docs/`

## Como ativar skills no Gemini

```bash
vault-skills activate --preset laravel-nova
vault-skills sync gemini
```

Isto instala skills nativas em `~/.gemini/skills/` e mantém o bundle agregado no projeto.

## Fluxo recomendado

```bash
vault-ai-init
vault-ai-context
.ai/agents/plan-creator.sh "Validar arquitetura"
vault-skills activate --preset laravel-nova
vault-skills sync gemini
```

## Exemplo de prompt

```text
Leia .ai/plans/validar-arquitetura.md, .ai/context/agent-context.md e .ai/skills/ACTIVE_SKILLS.md.
Investigue o código apenas para validar se o plano encaixa na estrutura atual.
```

## Quando usar Gemini antes de Claude

Use Gemini primeiro quando:

- ainda não está claro onde a mudança deve entrar
- existe dúvida sobre a arquitetura atual
- o código parece espalhado
- quer validar um plano antes de implementar

Depois disso, Claude pode entrar com escopo mais fechado para execução.

## Skills nativas vs bundle agregado

Use skills nativas do Gemini para comportamento especializado recorrente.

Use `.ai/skills/ACTIVE_SKILLS.md` quando:

- quiser o mesmo conjunto de skills partilhado com outros agentes
- precisar de fallback portátil
- estiver a alternar entre Gemini, Claude, Codex e outras ferramentas
