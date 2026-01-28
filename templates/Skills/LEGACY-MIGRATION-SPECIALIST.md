---
name: legacy-migration-specialist
description: Expert in migrating legacy Laravel applications without breaking production. Use when upgrading PHP 7.4 to 8.3, migrating Laravel Nova 2/3 to 4/5, transitioning Vue 2 to Vue 3, replacing Quasar with PrimeVue, or planning incremental refactoring strategies. Focuses on safe, production-ready migrations with minimal downtime and risk mitigation.
---

# Legacy Migration Specialist

Expert guidance for safely migrating legacy Laravel + Nova + Vue applications to modern versions.

## Migration Scenarios Covered

### 1. PHP Version Upgrades
- PHP 7.4 → 8.0 → 8.1 → 8.3
- Handling breaking changes incrementally
- Testing strategies for each version jump

### 2. Laravel Nova Upgrades
- Nova 2 → Nova 3
- Nova 3 → Nova 4
- Nova 4 → Nova 5
- Running multiple Nova versions simultaneously (if needed)

### 3. Frontend Framework Migration
- Vue 2 → Vue 3 (Composition API)
- Quasar → PrimeVue component replacement
- Maintaining Vue 2 alongside Vue 3 during transition

### 4. Laravel Framework Upgrades
- Laravel 8 → 9 → 10 → 11
- Coordinating with Nova and PHP upgrades

## Core Migration Principles

### 1. Never Big Bang Migrations
- Migrate incrementally, one layer at a time
- Keep production stable throughout
- Always have a rollback plan

### 2. Test-Driven Migration
- Write tests before migrating code
- Maintain test coverage during transition
- Use tests to verify backward compatibility

### 3. Feature Flags
- Use flags to toggle between old and new implementations
- Enable gradual rollout
- Quick rollback if issues arise

### 4. Dual-Run Strategy
- Run old and new code side-by-side
- Compare outputs to verify equivalence
- Switch over when confidence is high

## PHP Version Migration

### PHP 7.4 → 8.0 Migration Checklist

**Breaking Changes:**
1. **Named Arguments** - May conflict with parameter renames
2. **Union Types** - Update type hints where beneficial
3. **Null-Safe Operator** - Replace manual null checks: `$user?->profile?->name`
4. **Match Expression** - Modern alternative to switch
5. **Constructor Property Promotion** - Simplify model constructors

**Migration Steps:**
```bash
# 1. Update composer.json
"require": {
    "php": "^8.0"
}

# 2. Run rector for automated fixes
composer require rector/rector --dev
vendor/bin/rector process app/

# 3. Run PHPStan for static analysis
composer require phpstan/phpstan --dev
vendor/bin/phpstan analyse app/

# 4. Fix deprecations
# - Check error logs
# - Test thoroughly
```

**Common Issues:**
- String to number comparisons behave differently
- `@` error suppression changes
- Trailing commas now allowed everywhere
- `::class` on objects now allowed

### PHP 8.0 → 8.3 Migration

**New Features to Leverage:**
1. **Readonly Properties** (8.1) - Use in DTOs and Value Objects
2. **Enums** (8.1) - Replace status constants
3. **Readonly Classes** (8.2) - Immutable DTOs
4. **Disjunctive Normal Form Types** (8.2) - Complex type hints
5. **Typed Class Constants** (8.3) - Better type safety

**Example Enum Migration:**
```php
// Old (PHP 7.4)
class Order {
    const STATUS_PENDING = 'pending';
    const STATUS_PAID = 'paid';
    const STATUS_SHIPPED = 'shipped';
}

// New (PHP 8.1+)
enum OrderStatus: string {
    case PENDING = 'pending';
    case PAID = 'paid';
    case SHIPPED = 'shipped';
}
```

## Laravel Nova Migration

### Nova 2/3 → Nova 4 Migration

**Major Breaking Changes:**

1. **Authorization Changes**
```php
// Nova 2/3 - Gates
Gate::define('viewNova', function ($user) {
    return in_array($user->email, ['admin@app.com']);
});

// Nova 4 - Policies preferred
public static function authorizedToCreate(Request $request)
{
    return $request->user()->can('create', static::$model);
}
```

2. **Field API Changes**
```php
// Nova 2/3
public function fields()
{
    return [
        ID::make()->sortable(),
        Text::make('Name')->rules('required'),
    ];
}

// Nova 4 - Same structure but different internal handling
public function fields(Request $request)
{
    return [
        ID::make()->sortable(),
        Text::make('Name')->rules('required'),
    ];
}
```

3. **Actions API Changes**
```php
// Nova 2/3
public function handle(ActionFields $fields, Collection $models)
{
    foreach ($models as $model) {
        // Process
    }
}

// Nova 4
public function run(ActionFields $fields, Collection $models)
{
    foreach ($models as $model) {
        // Process
    }
}
```

4. **Filters Changes**
```php
// Nova 3
public function apply(Request $request, $query, $value)
{
    return $query->where('status', $value);
}

// Nova 4 - Same signature, but internal changes
public function apply(Request $request, $query, $value)
{
    return $query->where('status', $value);
}
```

### Nova 4 → Nova 5 Migration

**Key Changes:**
- Inertia.js upgrade (if you customized views)
- Vue 3 frontend (Nova's internal frontend)
- Updated asset compilation
- Custom field compatibility check required

**Migration Strategy:**
```bash
# 1. Update composer
composer require laravel/nova:"^5.0"

# 2. Publish and update assets
php artisan nova:publish
php artisan nova:assets

# 3. Review custom fields
# Check compatibility of custom Nova fields with Vue 3

# 4. Test all Resources individually
php artisan test --filter=NovaTest
```

### Running Multiple Nova Versions

**Scenario:** Large project with 100+ Resources, need gradual migration

**Strategy:**
```php
// Register different Nova instances by namespace
// config/nova.php
return [
    'resources' => [
        'v4' => app_path('Nova/V4'),
        'v5' => app_path('Nova/V5'),
    ],
];
```

**Note:** This is complex and should be last resort. Prefer full migration.

## Vue 2 → Vue 3 Migration

### Breaking Changes Checklist

1. **Filters Removed** - Replace with methods or computed properties
2. **$on/$off/$once Removed** - Use mitt or provide/inject
3. **Inline Template Attribute Removed** - Use render functions
4. **Keycode Modifiers Removed** - Use key names: `@keyup.enter`
5. **$children Removed** - Use refs or provide/inject
6. **$listeners Removed** - Just use `v-bind="$attrs"`

### Migration Strategy

**Phase 1: Create Vue 3 Compatibility Build**
```bash
# Install Vue 3 migration build
npm install @vue/compat
```

**Phase 2: Component by Component**
```javascript
// Old Vue 2 Options API
export default {
  data() {
    return { count: 0 }
  },
  methods: {
    increment() {
      this.count++
    }
  }
}

// New Vue 3 Composition API
import { ref } from 'vue'

export default {
  setup() {
    const count = ref(0)
    const increment = () => count.value++
    
    return { count, increment }
  }
}
```

**Phase 3: Replace Filters**
```javascript
// Old (Vue 2)
{{ price | currency }}

// New (Vue 3) - Use method
{{ formatCurrency(price) }}
```

**Phase 4: Event Bus Replacement**
```javascript
// Old (Vue 2)
this.$eventBus.$emit('update', data)

// New (Vue 3) - Use mitt
import mitt from 'mitt'
const emitter = mitt()
emitter.emit('update', data)
```

### Quasar → PrimeVue Migration

**Component Mapping:**

| Quasar | PrimeVue | Notes |
|--------|----------|-------|
| QBtn | Button | Similar API |
| QInput | InputText | Different events |
| QSelect | Dropdown | Data structure differs |
| QTable | DataTable | Complete rewrite needed |
| QDialog | Dialog | Props differ |
| QForm | Form wrapper | Create custom wrapper |
| QCard | Card | Similar structure |
| QToolbar | Toolbar | Similar concept |

**Migration Pattern:**
```vue
<!-- Old Quasar -->
<q-table
  :data="rows"
  :columns="columns"
  row-key="id"
/>

<!-- New PrimeVue -->
<DataTable 
  :value="rows"
  :columns="columns"
  dataKey="id"
/>
```

**Strategy:**
1. Create component mapping document
2. Migrate one view at a time
3. Keep routing separate (old and new routes)
4. Use feature flags to toggle between implementations

## Testing Strategy

### Pre-Migration Testing
```php
// Create baseline test suite
php artisan test --coverage

// Document current behavior
// tests/Legacy/BaselineTest.php
public function test_user_creation_flow()
{
    $response = $this->post('/users', $data);
    $this->assertDatabaseHas('users', ['email' => $data['email']]);
}
```

### During Migration Testing
- Run tests after each incremental change
- Compare behavior: old vs new implementation
- Monitor error logs closely
- Use staging environment for validation

### Post-Migration Testing
- Full regression test suite
- Performance testing (compare before/after)
- Load testing if traffic is significant
- User acceptance testing (UAT)

## Risk Mitigation

### 1. Feature Flags
```php
// config/features.php
return [
    'use_nova_v5' => env('FEATURE_NOVA_V5', false),
    'use_vue3_frontend' => env('FEATURE_VUE3', false),
];

// Usage
if (config('features.use_nova_v5')) {
    return new Nova5Resource();
}
return new Nova4Resource();
```

### 2. Database Backups
- Backup before each major migration step
- Test restore procedure
- Keep backups for at least 30 days

### 3. Rollback Plan
Document for each migration step:
- What changed
- How to rollback
- Dependencies affected
- Data migrations (if any)

### 4. Monitoring
- Set up error tracking (Sentry, Bugsnag)
- Monitor performance metrics
- Track user behavior changes
- Alert on anomalies

## Migration Timeline Template

### Week 1-2: Assessment
- Inventory current versions
- Identify dependencies
- Document customizations
- Plan migration order

### Week 3-4: PHP Upgrade
- PHP 7.4 → 8.0 in dev
- Fix deprecations
- Test thoroughly
- Deploy to staging
- Deploy to production (low-traffic time)

### Week 5-8: Nova Upgrade
- Nova 2/3 → 4 (or 4 → 5)
- Migrate resources one-by-one
- Test each resource
- Deploy incrementally

### Week 9-16: Frontend Migration
- Vue 2 → Vue 3 compatibility mode
- Migrate components to Composition API
- Replace Quasar with PrimeVue
- Deploy feature-flagged

### Week 17-18: Cleanup
- Remove legacy code
- Remove feature flags
- Update documentation
- Team training

## Common Pitfalls

1. **Trying to migrate everything at once** - Always incremental
2. **Skipping tests** - Tests are your safety net
3. **Not documenting changes** - Future you will thank you
4. **Ignoring deprecation warnings** - They become errors later
5. **Not testing on production-like data** - Use production DB dumps
6. **Assuming backward compatibility** - Always verify
7. **Skipping team training** - Team needs to understand changes

## When to Hire External Help

Consider external help if:
- Team lacks migration experience
- Critical business timeline
- Very complex customizations
- Risk of extended downtime
- Budget allows for it

## Success Metrics

Track these metrics throughout migration:
- Test coverage percentage
- Error rate (production)
- Performance (response times)
- User complaints/tickets
- Deployment frequency
- Rollback frequency (should be low)

Migration is successful when:
- All tests pass
- Performance equals or exceeds baseline
- Error rates return to normal
- Team is comfortable with new code
- No major incidents for 30 days
