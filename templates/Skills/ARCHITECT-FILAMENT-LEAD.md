---
name: architect-filament-lead
description: Pragmatic architectural decisions for Laravel 12 + Filament 5+ projects. Use when planning system architecture, defining data models, choosing between Filament vs custom solutions, establishing code organization patterns (Services, Actions, DTOs, Policies), handling upgrades to PHP 8.4, or making strategic technology decisions. Focuses on "why" and "how" at system level.
---

# Architect Filament Lead

Pragmatic architectural guidance for Laravel 12 + Filament 5+ ecosystems.

## Core Responsibilities

### 1. Architectural Decisions
- Choose between Filament Admin vs custom SPA vs hybrid approach
- Define boundaries: what belongs in Filament, what needs custom API, what goes to frontend
- Service Layer, Actions, DTOs, Repositories - when each pattern makes sense
- Multi-tenant architecture and complex authorization strategies using Filament

### 2. Modernization Strategy
- Plan for Filament 5 adoption
- PHP 8.4 + Laravel 12 features utilization (Property Hooks, new Laravel defaults)
- Database schema evolution

### 3. Data Architecture
- Database design: tables, relationships, indexes
- API contracts and versioning strategy
- Filament Resource structure vs API endpoints
- Query optimization strategies (eager loading patterns in Filament)

### 4. Code Organization
- Directory structure for multi-module projects
- Namespace organization (App\Services, App\Actions, App\DTOs)
- When to use Laravel packages vs inline code
- Filament customization organization (Resources, Pages, Widgets, Clusters)

## Decision Framework

### Filament vs Custom Solution
**Use Filament when:**
- Internal tools, Admin panels, Customer Portals (using Panel Builder)
- standard CRUD is 80% of the requirement
- Built-in authorization patterns work
- Fast time-to-market is critical

**Use Custom API + SPA when:**
- Highly specialized UI/UX requirements impossible with Filament components
- Consumer-facing mobile apps requiring native feel
- Real-time high-frequency trading interfaces
- Offline-first requirements

### Service Layer Decision
**Use Services when:**
- Complex business logic (> 50 lines)
- Logic reused across Controllers/Livewire Components/Jobs
- Multiple database operations coordinated
- External API integrations

**Skip Services when:**
- Simple CRUD operations
- Single Eloquent query
- No business logic (let Filament Actions handle it)

### DTO Pattern Decision
**Use DTOs when:**
- API contracts need validation
- Type safety critical
- Data transformation complex
- Multiple data sources combined

**Skip DTOs when:**
- Direct Eloquent model sufficient
- Simple request validation enough

## Architectural Patterns

### Recommended Structure
```
app/
├── Actions/           # Single-purpose operations
├── DTOs/             # Data Transfer Objects
├── Http/
│   ├── Controllers/  # Thin, delegate to Services (if API needed)
│   └── Requests/     # Validation
├── Models/           # Eloquent models
├── Filament/         # Filament resources/pages
├── Policies/         # Authorization
├── Services/         # Business logic
└── Support/          # Helpers, utilities
```

### Filament-Specific Organization
```
app/Filament/
├── Actions/          # Reusable Filament actions
├── Clusters/         # Grouped resources
├── Exports/          # Exporters
├── Imports/          # Importers
├── Pages/            # Custom pages
├── Resources/        # Main resources
└── Widgets/          # Dashboard widgets
```

## Anti-Patterns to Avoid

**Fat Livewire Components** - Move business logic to Services/Actions
**God Models** - Split responsibilities
**Filament Resources as API** - Use proper API controllers for external consumption
**Over-customizing Filament Views** - If you fight the framework too much, build a custom page or separate app
**Premature optimization** - Solve actual bottlenecks

## Performance Considerations

### Query Strategy
- Always use `modifyQueryUsing` in Filament Tables for eager loading (`with()`)
- Use `counts()` instead of `count()` on relationships
- Consider database indexes for common table filters
- Use `lazy()` loading for heavy widgets

### Caching Strategy
- Cache expensive queries (> 500ms)
- Cache complex permissions checks
- Cache computed attributes on models
- Use Redis for session/cache in production

## Migration Strategy Guidance

### PHP Version Migration (to 8.4)
**8.3 → 8.4:**
- **Property Hooks:** Refactor DTOs and Models to use Property Hooks for cleaner getters/setters.
- **Array Find:** Use `array_find` instead of loops or collection wrappers for simple array searches.
- **New Array/String functions:** Leverage new multibyte string functions.

### Laravel Migration (to 12)
**11 → 12:**
- Review application skeleton changes.
- Update dependencies.
- Check for breaking changes in first-party packages.

## Security Architecture

### Authorization Layers
1. Gate/Policy level (model operations)
2. Filament Resource level (canViewAny, canCreate, etc.)
3. Filament Action level (visible/hidden)
4. API level (middleware, Sanctum)

### Data Access Patterns
- Always scope queries by authenticated user (Tenancy)
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
