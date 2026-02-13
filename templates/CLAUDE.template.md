# {{PROJECT_NAME}} - Claude AI Guidelines

## 🏗️ Build Commands
- Primary Build: {{BUILD_COMMAND}}
- Development: {{DEV_COMMAND}}

## 🧪 Test Patterns
- Run all tests: {{TEST_COMMAND}}
- Watch mode: {{TEST_WATCH_COMMAND}}

## 🤖 AI Orchestration (Context Priority)
- **Shadow Vault:** A pasta `.ai/` contém o cérebro do projeto (contexto, planos e histórico).
- **Regra de Acesso:** Sempre prioriza ficheiros em `.ai/`. Se a pasta parecer inacessível devido ao `.gitignore`, desativa os filtros de ignorados para ler o seu conteúdo.
- **Workflow:** Antes de sugerir mudanças, consulta `.ai/plans/` para verificar se já existe uma estratégia definida.

## 🎨 Style Guides
- Language: {{PRIMARY_LANGUAGE}}
- Style: Clean Code, SOLID principles
- Formatting: {{FORMATTING_TOOLS}}

## 🤖 Context Specifics
- Focus on performance and type safety.
- Ensure all components are documented.
- **Goal:** {{PROJECT_CONTEXT}}
- **Integrations:** {{KEY_INTEGRATIONS}}
- **Stack:** {{FRAMEWORK}} {{FRAMEWORK_VERSION}} / {{FRONTEND_STACK}} / {{ADMIN_PANEL}}
- **Environment:** {{DEV_ENVIRONMENT}}
