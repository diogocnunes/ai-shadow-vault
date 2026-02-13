# {Project Name} - Claude AI Guidelines

## 🏗️ Build Commands
- Primary Build: `npm run build`
- Development: `npm run dev`

## 🧪 Test Patterns
- Run all tests: `npm test`
- Watch mode: `npm test -- --watch`

## 🤖 AI Orchestration (Context Priority)
- **Shadow Vault:** A pasta `.ai/` contém o cérebro do projeto (contexto, planos e histórico).
- **Regra de Acesso:** Sempre prioriza ficheiros em `.ai/`. Se a pasta parecer inacessível devido ao `.gitignore`, desativa os filtros de ignorados para ler o seu conteúdo.
- **Workflow:** Antes de sugerir mudanças, consulta `.ai/plans/` para verificar se já existe uma estratégia definida.

## 🎨 Style Guides
- Language: TypeScript / JavaScript
- Style: Clean Code, SOLID principles
- Formatting: Prettier / ESLint

## 🤖 Context Specifics
- Focus on performance and type safety.
- Ensure all components are documented.
