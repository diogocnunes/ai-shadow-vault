# AI Shadow Vault - Project Rules

## 🧬 Core Architecture & Patterns
- **Standard:** {{FRAMEWORK}} {{FRAMEWORK_VERSION}} / PHP {{PHP_VERSION}}
- **Patterns:** Service Layer for business logic, Actions for single-purpose operations, DTOs for type-safe data transfer.
- **Admin Panel:** {{ADMIN_PANEL}} {{ADMIN_VERSION}}
- **Frontend:** {{FRONTEND_STACK}} {{FRONTEND_VERSION}} ({{UI_LIBRARY}})

## 💎 Code Quality Standards
- **Type Safety:** Strict typing is mandatory. Every parameter, return, and property must be typed (PHP {{PHP_VERSION}}+).
- **Static Analysis:** Code must pass Larastan Level 9. Use PHPDoc generics for collections: `Collection<int, Model>`.
- **Magic Numbers:** No magic numbers. Use class constants with descriptive names.
- **Refactoring:** Prefer early returns, match expressions, and constructor property promotion.

## 🛠️ Backend Implementation
- **Eloquent:** Prevent N+1 by eager loading in `indexQuery`. Use `withCount` for aggregations.
- **Security:** Always use Eloquent or parameter binding to prevent SQL injection. Implement mass assignment protection via `$fillable`.
- **Authorization:** Mandatory Policies for all models. Use `Gate` only for global checks.
- **Migrations:** Use foreign key constraints and appropriate indexes for performance.

## 💾 Cache & Performance Rules
- **Cache Priority:** Before performing any external search or documentation query, **ALWAYS** check the local cache in `.ai/cache/` and `.ai/docs/`.
- **Documentation:** Prioritize existing documentation in the `.ai/` folder over general knowledge.
- **Optimization:** Cache expensive queries and Nova permissions when necessary.

## 📝 Query Priority
1. **Local Context:** `.ai/context/`
2. **Local Cache:** `.ai/cache/`
3. **Local Docs:** `.ai/docs/`
4. **Local Plans:** `.ai/plans/`
5. **External Search:** Only if information is missing locally.
