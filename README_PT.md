# AI Shadow Vault

AI Shadow Vault é uma camada local de contexto para desenvolvimento com IA. Ele guarda o contexto do projeto fora do repositório, liga os ficheiros certos de volta ao projeto e gera um resumo portátil em `.ai/context/agent-context.md`.

## Forma do Produto

O AI Shadow Vault passa a ter duas camadas:

- `core`: resolução do vault, workspace local `.ai/`, symlinks, sessões/histórico e contexto gerado
- `extensions`: workflows opcionais como review, user stories e sincronização de skills

A instalação padrão agora é intencionalmente enxuta. Workflows opcionais precisam ser ativados por projeto.

## O que fica no Core

- resolução estável do projeto e de worktrees
- storage externo em `~/.ai-shadow-vault-data`
- bootstrap da workspace local `.ai/`
- ligação de `GEMINI.md`, `CLAUDE.md`, `AGENTS.md` e regras de editores
- fluxo de salvar/retomar sessão
- geração de `.ai/context/agent-context.md`
- integração de shell e health checks

## Extensões Opcionais

Listar extensões disponíveis:

```bash
vault-ext list
```

Ativar uma extensão dentro do projeto:

```bash
vault-ext enable planning
vault-ext enable review
vault-ext enable skills
```

Grupos embutidos atualmente:

- `planning`: workflow de breakdown com user stories
- `review`: preparação de prompts de code review
- `skills`: ativação e sync de skills universais
- `laravel-stack`: reservado para workflows opcionais específicos de Laravel

Pacotes externos catalogados:

- `superpowers-laravel`: pacote upstream de superpowers para Laravel
- `user-stories-skill`: pacote upstream de planeamento com user stories
- `code-review-skill`: pacote upstream de review

Inspecionar uma extensão:

```bash
vault-ext info superpowers-laravel
vault-ext info user-stories-skill
vault-ext info code-review-skill
```

Comandos legados como `vault-review`, `vault-user-stories` e `vault-skills` continuam a funcionar, mas agora são tratados como workflows opcionais, não como parte implícita do core.

## Instalação

```bash
git clone https://github.com/diogocnunes/ai-shadow-vault.git ~/.ai-shadow-vault
mkdir -p ~/.ai-shadow-vault-data
```

Adicione isto ao `~/.zshrc`:

```bash
source ~/.ai-shadow-vault/scripts/shell_integration.zsh
```

Reabra o terminal e inicialize o projeto:

```bash
cd ~/Sites/meu-projeto
vault-init
```

Se quiser refazer a configuração interativa:

```bash
vault-init --force-config
```

## Fluxo de Update

Atualizar o pacote:

```bash
cd ~/Sites/meu-projeto
vault-update
source ~/.ai-shadow-vault/scripts/shell_integration.zsh
```

Agora o `vault-update` refresca apenas o estado core do projeto:

- corre `vault-init --non-interactive`
- regenera `.ai/context/agent-context.md`
- executa hooks de extensões já ativadas

Ele deixou de executar setup de workflows opcionais por omissão.

## Comandos Principais

Core:

- `vault-init`
- `vault-update`
- `vault-ai-context`
- `vault-ai-save`
- `vault-ai-resume`
- `vault-ai-stats`
- `vault-check`
- `cc`
- `vault-ext`

Workflows opcionais:

- `vault-review`
- `vault-user-stories`
- `vault-breakdown`
- `vault-skills`

## Quick Start

Setup base:

```bash
cd ~/Sites/meu-projeto
vault-init
vault-ai-context
```

Ativar workflow de planning:

```bash
vault-ext enable planning
vault-user-stories "Implementar login OAuth"
```

Ativar workflow de review:

```bash
vault-ext enable review
vault-review --scope staged
```

Ativar workflow de skills:

```bash
vault-ext enable skills
vault-skills activate --preset reviewing
vault-skills sync native context editors
```

## Workspace Local

Caminhos importantes:

| Caminho | Função |
| :--- | :--- |
| `.ai/rules.md` | regras do projeto |
| `.ai/plans/` | planos locais |
| `.ai/docs/` | documentação local |
| `.ai/context/archive/` | sessões arquivadas |
| `.ai/context/agent-context.md` | resumo gerado para agentes |
| `.ai/extensions/enabled.txt` | extensões opcionais ativadas |
| `.ai/skills/ACTIVE_SKILLS.md` | bundle opcional de skills, quando usado |

## Suporte de SO

Suporte atual:

- `macOS`: suportado
- `Linux`: não suportado
- `Windows`: não suportado

O pacote continua a ser macOS-first por enquanto.

## Notas de Migração

Se vem da `1.x` ou de uma `2.x` anterior com comportamento “batteries included”:

1. Corra `vault-update`
2. Corra `vault-init --non-interactive`
3. Reative apenas os workflows que ainda quer com `vault-ext enable ...`
4. Regere o contexto com `vault-ai-context`

Exemplos:

```bash
vault-ext enable planning review
vault-ext enable skills
```

## Créditos

Alguns workflows opcionais foram inspirados por ou adaptados de:

- `jpcaparas/superpowers-laravel`
- `felipereisdev/user-stories-skill`
- `felipereisdev/code-review-skill`
