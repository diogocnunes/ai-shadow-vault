---
name: architect-lead
description: Pragmatic architectural decisions for Laravel + Nova projects with legacy considerations. Use when planning system architecture, defining data models, choosing between Nova vs custom solutions, establishing code organization patterns (Services, Actions, DTOs, Policies), handling multi-version coexistence (Nova 2-5, PHP 7.4-8.3), or making strategic technology decisions. Not for implementation details - focuses on "why" and "how" at system level.
---

# Architect Lead

Pragmatic architectural guidance for Laravel + Nova ecosystems with legacy system considerations.

## Core Responsibilities

### 1. Architectural Decisions
- Choose between Laravel Nova admin vs custom SPA vs hybrid approach
- Define boundaries: what belongs in Nova, what needs custom API, what goes to frontend
- Service Layer, Actions, DTOs, Repositories - when each pattern makes sense
- Multi-tenant architecture and complex authorization strategies

### 2. Legacy Coexistence Strategy
- Plan for Nova 2/3 alongside Nova 4/5 in same codebase
- PHP 7.4 + Laravel 8 coexisting with PHP 8.3 + Laravel 11
- Vue 2 (Quasar) alongside Vue 3 (PrimeVue) migration paths
- Database schema evolution across versions

### 3. Data Architecture
- Database design: tables, relationships, indexes
- API contracts and versioning strategy
- Nova Resource structure vs API endpoints
- Query optimization strategies (eager loading patterns)

### 4. Code Organization
- Directory structure for multi-module projects
- Namespace organization (App\Services, App\Actions, App\DTOs)
- When to use Laravel packages vs inline code
- Nova customization organization (Fields, Filters, Actions, Lenses)

## Decision Framework

### Nova vs Custom Solution
**Use Nova when:**
- Standard CRUD with minimal customization
- Admin-only interface
- Built-in authorization patterns work
- Performance acceptable (< 10k records per resource)

**Use Custom API + SPA when:**
- Complex UX requirements
- Public-facing interfaces
- Real-time updates needed
- Heavy client-side interactivity
- Performance critical (> 50k records)

**Use Hybrid when:**
- Admin uses Nova for management
- Users get custom SPA experience
- Shared API layer serves both

### Service Layer Decision
**Use Services when:**
- Complex business logic (> 50 lines)
- Logic reused across Controllers/Commands/Jobs
- Multiple database operations coordinated
- External API integrations

**Skip Services when:**
- Simple CRUD operations
- Single Eloquent query
- No business logic

### DTO Pattern Decision
**Use DTOs when:**
- API contracts need validation
- Type safety critical
- Data transformation complex
- Multiple data sources combined

**Skip DTOs when:**
- Direct Eloquent model sufficient
- Simple request validation enough
- No transformation needed

## Architectural Patterns

### Recommended Structure
```
app/
├── Actions/           # Single-purpose operations
├── DTOs/             # Data Transfer Objects
├── Http/
│   ├── Controllers/  # Thin, delegate to Services
│   └── Requests/     # Validation
├── Models/           # Eloquent models
├── Nova/             # Nova resources
├── Policies/         # Authorization
├── Services/         # Business logic
└── Support/          # Helpers, utilities
```

### Nova-Specific Organization
```
app/Nova/
├── Actions/          # Nova actions
├── Dashboards/       # Metrics dashboards
├── Filters/          # Custom filters
├── Lenses/          # Alternative views
├── Metrics/         # KPI cards
└── Resources/       # Main resources
```

## Anti-Patterns to Avoid

**Fat Controllers** - Move logic to Services
**God Models** - Split responsibilities
**Nova Resources as API** - Use proper API controllers
**Mixing Nova logic in Controllers** - Keep separate
**Over-abstracting** - Prefer clear over clever
**Premature optimization** - Solve actual bottlenecks

## Performance Considerations

### Query Strategy
- Always use `indexQuery()` in Nova Resources for optimization
- Eager load relationships by default
- Use `counts()` instead of `count()` on relationships
- Consider database indexes for common filters

### Caching Strategy
- Cache expensive queries (> 500ms)
- Cache Nova permissions when complex
- Cache computed attributes on models
- Use Redis for session/cache in production

### When to Optimize
- Nova Resources with > 10k records
- Filters on large datasets
- Complex authorization logic
- Computed metrics/aggregations

## Migration Strategy Guidance

### Nova Version Migration Path
**Nova 2/3 → Nova 4:**
- Update resource syntax (fields array)
- Update authorization (gates → policies)
- Update actions (handle → run)
- Test each resource individually

**Nova 4 → Nova 5:**
- Update Inertia components if customized
- Review breaking changes in custom fields
- Update asset compilation

### PHP Version Migration
**7.4 → 8.0:**
- Fix named arguments issues
- Update null safety
- Test union types compatibility

**8.0 → 8.3:**
- Use readonly properties where applicable
- Leverage enums for status fields
- Test deprecation warnings

## Security Architecture

### Authorization Layers
1. Gate/Policy level (model operations)
2. Nova Resource level (viewAny, view, create, update, delete)
3. Nova Field level (canSee, canUpdate)
4. API level (middleware, request validation)

### Data Access Patterns
- Always scope queries by authenticated user when relevant
- Use Policy::before() for admin overrides
- Implement soft deletes for audit trail
- Log sensitive operations

## Decision Documentation

For each major architectural decision, document:
1. **Context** - What problem are we solving?
2. **Options** - What alternatives were considered?
3. **Decision** - What did we choose and why?
4. **Consequences** - What are the tradeoffs?

Keep architecture decisions in `docs/architecture/` directory.
