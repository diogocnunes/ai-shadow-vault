# 🧠 Claude Code + AI Shadow Vault: Workflow FAQ

Este guia explica como utilizar o sistema de cache e os scripts do Shadow Vault para maximizar a eficiência e economizar tokens no Claude Code.

---

### 1. O que é o comando `cc`?
O `cc` (atalho para `claude-start`) é o seu **ritual de entrada**. Ele prepara o terreno antes de você começar a codar.
- **O que ele faz:**
  1. Exibe o resumo da última sessão (`vault-ai-resume`).
  2. Lista os planos ativos.
  3. Copia automaticamente as regras de comportamento de `.ai/rules.md` para o seu clipboard (Ctrl+V).
- **Como usar:** Rode `cc` no terminal, veja o que foi feito por último, abra o `claude` e cole as regras no primeiro prompt.

### 2. `plan-creator.sh` vs. Modo `/plan` do Claude
Esta é a dúvida mais comum. Aqui está a diferença:

| Característica | `plan-creator.sh` | Modo `/plan` do Claude |
| :--- | :--- | :--- |
| **Onde roda** | No terminal (fora ou dentro do Claude com `!`) | Dentro do Claude Code |
| **Saída** | Um arquivo físico em `.ai/plans/nome.md` | Um raciocínio temporário na memória do chat |
| **Propósito** | **Estratégia:** Define a arquitetura e regras de negócio. | **Tática:** Define quais linhas de código mudar agora. |
| **Custo** | Zero tokens (script local). | Tokens de "raciocínio" e leitura de arquivos. |

**Dica:** Sempre use o `plan-creator.sh` primeiro para definir *o que* fazer. Depois, peça para o Claude ler esse arquivo e usar o `/plan` para decidir *como* implementar.

### 3. Como usar o `plan-creator.sh`?
Você deve usá-lo sempre que for iniciar uma nova funcionalidade ou uma tarefa complexa.
- **Exemplo:** `! .ai/agents/plan-creator.sh "Criar Menu de Contexto"`
- **Por que usar:** Ele força a IA a seguir os templates de "Expert" que definimos (ex: não colocar lógica no Controller, usar Services, seguir padrões Filament V5). Sem um plano físico, o Claude pode "improvisar" e fugir dos padrões do seu projeto.

### 4. O Fluxo de Trabalho Ideal (Passo-a-Passo)

1.  **Preparação:** No terminal, digite `cc`.
2.  **Planejamento:** Crie o plano da task: `.ai/agents/plan-creator.sh "Minha Nova Task"`.
3.  **Execução:** Entre no Claude Code (`claude`).
4.  **Contextualização:**
    - Cole o conteúdo do clipboard (as regras).
    - Diga: *"Siga o plano em .ai/plans/minha-nova-task.md. O resumo da última sessão está na tela do meu terminal."*
5.  **Finalização:** Ao terminar, saia do Claude e rode `vault-ai-save`. Isso arquiva o progresso e limpa o `session.md` para a próxima vez.

---

### 5. Evidência de Economia (Tokens & Dinheiro)

O uso do Shadow Vault não é apenas organização, é redução de custos.

| Ação | Sem Shadow Vault | Com Shadow Vault | Economia Estimada |
| :--- | :--- | :--- | :--- |
| **Contexto Inicial** | 5k - 15k tokens (Lendo o diretório) | < 1k tokens (Lendo `rules.md` e `plan.md`) | **~90%** |
| **Definição de Task** | 2k - 4k tokens (Explicando o que quer) | < 500 tokens (Apontando para o `plan.md`) | **~85%** |
| **Documentação** | 3k - 8k tokens (IA buscando na web) | 500 - 1k tokens (Lendo `.md` local) | **~70%** |
| **Continuidade** | Re-envio do histórico longo | Resumo da sessão anterior (Resume) | **~60%** |

*Nota: Em projetos grandes, isso pode significar a diferença entre gastar $1.00 ou $0.10 por funcionalidade implementada.*

---

### 6. Dicas de Prompts Econômicos

- **Evite:** *"Claude, analise o projeto inteiro e me diga o que fazer para criar um menu."* (Isso gasta milhares de tokens lendo arquivos desnecessários).
- **Prefira:** *"Claude, leia o plano em `.ai/plans/menu.md`. Eu vou te fornecer o código do arquivo `App/Models/User.php` para começarmos o Passo 1."*

---
*Este FAQ foi gerado para garantir que a inteligência artificial trabalhe para você (e para o seu bolso), mantendo a arquitetura do projeto sempre limpa.*
