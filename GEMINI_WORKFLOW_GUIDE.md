# ♊ Gemini CLI + AI Shadow Vault: Workflow & Contexto

O Gemini CLI opera de forma diferente do Claude Code. Enquanto o Claude é excelente para "Plan e Execute" em arquivos específicos, o Gemini CLI é um **Agente Investigador**.

---

### 1. O Gemini é mais inteligente com o contexto?
**Sim.** O Gemini CLI tem a capacidade de:
- **Investigar:** Usar o `codebase_investigator` para mapear dependências sem que você precise ler os arquivos.
- **Memorizar:** Usar o `save_memory` para guardar fatos sobre você e suas preferências que persistem entre projetos.
- **Auto-Recap:** Ele lê o arquivo `.gemini/GEMINI.md` automaticamente no início de cada conversa.

### 2. Os scripts `vault-*` funcionam com o Gemini?
**Sim, e devem ser usados.** 
Embora o Gemini consiga investigar o código sozinho, isso consome tokens e tempo. Se você já tem um plano em `.ai/plans/`, o Gemini chegará à solução muito mais rápido.

### 3. Fluxo de Trabalho Integrado

1.  **Sincronização de Memória:**
    - O Gemini escreve memórias importantes em `.gemini/GEMINI.md`.
    - O script `vault-ai-save` pode ser usado para consolidar essas memórias no arquivo central de conhecimento do Vault.

2.  **O "Double-Check" de Arquitetura:**
    - Peça ao Gemini: *"Use o `codebase_investigator` para validar se o plano em `.ai/plans/meu-plano.md` é viável na estrutura atual"*.
    - Isso une a **estratégia** do seu plano com a **visão real** da IA sobre o código.

3.  **Uso dos Agentes:**
    - Você pode pedir ao Gemini: *"Rode o script `.ai/agents/doc-fetcher.sh "Laravel"` e me explique como integrar com o que descobriu no projeto"*.

### 4. Onde o Gemini economiza mais?

| Funcionalidade | Vantagem do Gemini | Impacto no Cache |
| :--- | :--- | :--- |
| **Codebase Investigator** | Não precisa ler todos os arquivos. | Ele valida o que está no cache do `.ai/`. |
| **Save Memory** | Lembra de preferências globais. | Evita repetir "Eu prefiro usar Tailwind" em cada chat. |
| **Context Window** | Janela de 2M de tokens. | Permite carregar documentos técnicos inteiros se necessário. |

### 5. Dica de Prompt para Gemini CLI
*"Gemini, analise o contexto em `.gemini/GEMINI.md` e o plano em `.ai/plans/task.md`. Use suas ferramentas de investigação apenas se encontrar inconsistências entre o plano e o código real."*

---
**Resumo:** Use o Claude Code para **construir** (execução rápida e precisa) e o Gemini CLI para **arquitetar e investigar** (análise profunda e memória de longo prazo). Ambos compartilham a mesma "fonte da verdade": a pasta `.ai/`.
