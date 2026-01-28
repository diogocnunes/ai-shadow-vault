---
name: backend-expert
description: Deep expertise in PHP 8.3/7.4 and Laravel 11/8 development with Laravel Nova 2-5 specialization. Use for implementing Models, Migrations, Controllers, Services, Middlewares, Policies, Nova Resources (Fields, Actions, Filters, Lenses), API development, Eloquent optimization, security patterns, and backend architecture. Focuses on production-ready, performant, and secure Laravel applications.
---

# Backend Expert

Expert implementation guidance for Laravel + Nova backend development.

## Stack Coverage

### Primary Stack
- PHP 8.3
- Laravel 11
- Laravel Nova 5

### Legacy Support
- PHP 7.4
- Laravel 8
- Laravel Nova 2/3/4

## Core Implementation Areas

### 1. Eloquent Models
- Model structure and relationships
- Accessors, mutators, and casts
- Scopes (global and local)
- Events and observers
- Soft deletes and paranoid models

### 2. Migrations
- Schema design patterns
- Index strategies
- Foreign key constraints
- Data migrations vs schema migrations

### 3. Controllers & Services
- Thin controllers pattern
- Service layer organization
- Request validation
- Resource transformers

### 4. Laravel Nova Resources
- Field definitions and customization
- Authorization (viewAny, view, create, update, delete, restore, forceDelete)
- Filters, Lenses, Actions, Metrics
- Performance optimization (indexQuery, relatableQuery)
- Custom fields

### 5. Security & Authorization
- Policies implementation
- Gates for global checks
- Mass assignment protection
- SQL injection prevention
- XSS protection

## Laravel Nova Deep Dive

### Nova Resource Structure

```php
<?php

namespace App\Nova;

use Laravel\Nova\Resource as NovaResource;
use Laravel\Nova\Fields\{ID, Text, BelongsTo, HasMany};
use Laravel\Nova\Http\Requests\NovaRequest;

class User extends NovaResource
{
    // Model binding
    public static $model = \App\Models\User::class;
    
    // Resource configuration
    public static $title = 'name';
    public static $search = ['id', 'name', 'email'];
    public static $perPageViaRelationship = 5;
    
    // Performance optimization
    public static function indexQuery(NovaRequest $request, $query)
    {
        // Always eager load to prevent N+1
        return $query->with('team', 'role');
    }
    
    // Authorization
    public static function authorizedToCreate(NovaRequest $request)
    {
        return $request->user()->can('create', static::$model);
    }
    
    // Fields
    public function fields(NovaRequest $request)
    {
        return [
            ID::make()->sortable(),
            
            Text::make('Name')
                ->rules('required', 'max:255')
                ->sortable(),
            
            Text::make('Email')
                ->rules('required', 'email', 'unique:users,email,{{resourceId}}')
                ->creationRules('unique:users,email')
                ->updateRules('unique:users,email,{{resourceId}}'),
            
            BelongsTo::make('Team')
                ->searchable()
                ->withSubtitles(),
            
            HasMany::make('Posts'),
        ];
    }
    
    // Filters
    public function filters(NovaRequest $request)
    {
        return [
            new Filters\UserRole,
            new Filters\UserStatus,
        ];
    }
    
    // Actions
    public function actions(NovaRequest $request)
    {
        return [
            (new Actions\ActivateUser)
                ->confirmText('Are you sure you want to activate this user?')
                ->confirmButtonText('Activate')
                ->cancelButtonText('Cancel')
                ->canRun(fn($request, $model) => $request->user()->isAdmin()),
        ];
    }
    
    // Cards (Metrics)
    public function cards(NovaRequest $request)
    {
        return [
            new Metrics\NewUsers,
            new Metrics\UsersPerRole,
        ];
    }
}
```

### Custom Nova Fields

```php
<?php

namespace App\Nova\Fields;

use Laravel\Nova\Fields\Field;

class StatusBadge extends Field
{
    public $component = 'status-badge';
    
    public function __construct($name, $attribute = null, callable $resolveCallback = null)
    {
        parent::__construct($name, $attribute, $resolveCallback);
        
        $this->withMeta([
            'colors' => [
                'active' => 'green',
                'inactive' => 'red',
                'pending' => 'yellow',
            ],
        ]);
    }
    
    public function colors(array $colors)
    {
        return $this->withMeta(['colors' => $colors]);
    }
}

// Usage
StatusBadge::make('Status')
    ->colors([
        'approved' => 'green',
        'rejected' => 'red',
        'pending' => 'orange',
    ]),
```

### Nova Actions

```php
<?php

namespace App\Nova\Actions;

use Illuminate\Bus\Queueable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Support\Collection;
use Laravel\Nova\Actions\Action;
use Laravel\Nova\Fields\ActionFields;
use Laravel\Nova\Fields\{Select, Textarea};
use Laravel\Nova\Http\Requests\NovaRequest;

class UpdateStatus extends Action
{
    use InteractsWithQueue, Queueable;
    
    // UI Configuration
    public $name = 'Update Status';
    public $confirmText = 'Are you sure you want to update status?';
    public $confirmButtonText = 'Update';
    public $cancelButtonText = 'Cancel';
    
    // Run on queue
    public $withoutActionEvents = false;
    
    public function handle(ActionFields $fields, Collection $models)
    {
        foreach ($models as $model) {
            $model->update([
                'status' => $fields->status,
                'notes' => $fields->notes,
            ]);
        }
        
        return Action::message('Status updated successfully!');
    }
    
    public function fields(NovaRequest $request)
    {
        return [
            Select::make('Status')
                ->options([
                    'pending' => 'Pending',
                    'approved' => 'Approved',
                    'rejected' => 'Rejected',
                ])
                ->rules('required'),
            
            Textarea::make('Notes')
                ->rules('nullable', 'max:500'),
        ];
    }
}
```

### Nova Filters

```php
<?php

namespace App\Nova\Filters;

use Illuminate\Http\Request;
use Laravel\Nova\Filters\Filter;

class UserRole extends Filter
{
    public $name = 'Role';
    
    public function apply(Request $request, $query, $value)
    {
        return $query->where('role', $value);
    }
    
    public function options(Request $request)
    {
        return [
            'Administrator' => 'admin',
            'Editor' => 'editor',
            'Viewer' => 'viewer',
        ];
    }
}

// Date Range Filter
class DateRange extends Filter
{
    public $component = 'date-range-filter';
    
    public function apply(Request $request, $query, $value)
    {
        return $query->whereBetween('created_at', [
            $value['from'],
            $value['to'],
        ]);
    }
}
```

### Nova Lenses

```php
<?php

namespace App\Nova\Lenses;

use Laravel\Nova\Lenses\Lens;
use Laravel\Nova\Http\Requests\{LensRequest, NovaRequest};
use Laravel\Nova\Fields\{ID, Text, DateTime};

class MostActiveUsers extends Lens
{
    public function query(LensRequest $request, $query)
    {
        return $request->withOrdering($request->withFilters(
            $query->select('users.*')
                ->withCount('posts')
                ->orderBy('posts_count', 'desc')
        ));
    }
    
    public function fields(NovaRequest $request)
    {
        return [
            ID::make()->sortable(),
            Text::make('Name')->sortable(),
            Text::make('Posts Count', 'posts_count')->sortable(),
            DateTime::make('Last Post', 'last_posted_at')->sortable(),
        ];
    }
}
```

### Nova Metrics

```php
<?php

namespace App\Nova\Metrics;

use Laravel\Nova\Metrics\Value;
use Laravel\Nova\Http\Requests\NovaRequest;

class NewUsers extends Value
{
    public function calculate(NovaRequest $request)
    {
        return $this->count($request, \App\Models\User::class)
            ->label('New Users');
    }
    
    public function ranges()
    {
        return [
            7 => '7 Days',
            30 => '30 Days',
            60 => '60 Days',
            365 => '365 Days',
        ];
    }
}

// Trend Metric
class UsersOverTime extends Trend
{
    public function calculate(NovaRequest $request)
    {
        return $this->countByDays($request, \App\Models\User::class);
    }
}

// Partition Metric
class UsersPerRole extends Partition
{
    public function calculate(NovaRequest $request)
    {
        return $this->count($request, \App\Models\User::class, 'role')
            ->label(fn($value) => ucfirst($value));
    }
}
```

## Eloquent Optimization Patterns

### N+1 Query Prevention

```php
// BAD - N+1 queries
$users = User::all();
foreach ($users as $user) {
    echo $user->team->name; // Queries for each user
}

// GOOD - Eager loading
$users = User::with('team')->get();
foreach ($users as $user) {
    echo $user->team->name; // No extra queries
}

// BETTER - Eager load counts
$users = User::withCount('posts')->get();
foreach ($users as $user) {
    echo $user->posts_count; // No queries
}

// BEST - Select only needed columns
$users = User::select('id', 'name', 'team_id')
    ->with('team:id,name')
    ->get();
```

### Query Scopes

```php
// Model: app/Models/User.php
class User extends Model
{
    // Local scope
    public function scopeActive($query)
    {
        return $query->where('status', 'active');
    }
    
    public function scopeRole($query, $role)
    {
        return $query->where('role', $role);
    }
    
    // Global scope (always applied)
    protected static function booted()
    {
        static::addGlobalScope('active', function ($query) {
            $query->where('status', 'active');
        });
    }
}

// Usage
$admins = User::active()->role('admin')->get();
```

### Database Indexes

```php
// Migration
Schema::create('posts', function (Blueprint $table) {
    $table->id();
    $table->foreignId('user_id')->constrained()->cascadeOnDelete();
    $table->string('title');
    $table->text('content');
    $table->enum('status', ['draft', 'published'])->default('draft');
    $table->timestamp('published_at')->nullable();
    $table->timestamps();
    
    // Indexes for common queries
    $table->index('status');
    $table->index('published_at');
    $table->index(['user_id', 'status']); // Composite index
    $table->fullText(['title', 'content']); // Full-text search (MySQL 5.7+)
});
```

## Service Layer Pattern

```php
<?php

namespace App\Services;

use App\Models\User;
use App\DTOs\CreateUserData;
use Illuminate\Support\Facades\{DB, Hash};

class UserService
{
    public function create(CreateUserData $data): User
    {
        return DB::transaction(function () use ($data) {
            $user = User::create([
                'name' => $data->name,
                'email' => $data->email,
                'password' => Hash::make($data->password),
            ]);
            
            $user->assignRole($data->role);
            
            event(new UserCreated($user));
            
            return $user;
        });
    }
    
    public function update(User $user, array $data): User
    {
        return DB::transaction(function () use ($user, $data) {
            $user->update($data);
            
            if (isset($data['role'])) {
                $user->syncRoles([$data['role']]);
            }
            
            return $user->fresh();
        });
    }
}
```

## Security Best Practices

### Mass Assignment Protection

```php
// Model
class User extends Model
{
    // Option 1: Whitelist (recommended)
    protected $fillable = ['name', 'email', 'password'];
    
    // Option 2: Blacklist (use carefully)
    protected $guarded = ['id', 'is_admin'];
    
    // Hidden from JSON
    protected $hidden = ['password', 'remember_token'];
    
    // Casts
    protected $casts = [
        'email_verified_at' => 'datetime',
        'is_admin' => 'boolean',
        'settings' => 'array',
    ];
}
```

### SQL Injection Prevention

```php
// BAD - SQL Injection vulnerable
$email = request('email');
$users = DB::select("SELECT * FROM users WHERE email = '{$email}'");

// GOOD - Parameter binding
$users = DB::select('SELECT * FROM users WHERE email = ?', [$email]);

// BETTER - Query Builder (automatic escaping)
$users = User::where('email', $email)->get();

// BEST - Eloquent with scope
$users = User::whereEmail($email)->get();
```

### Authorization with Policies

```php
<?php

namespace App\Policies;

use App\Models\{User, Post};

class PostPolicy
{
    // Check before all other methods
    public function before(User $user, $ability)
    {
        if ($user->isAdmin()) {
            return true;
        }
    }
    
    public function viewAny(User $user): bool
    {
        return true;
    }
    
    public function view(User $user, Post $post): bool
    {
        return true;
    }
    
    public function create(User $user): bool
    {
        return $user->can('create posts');
    }
    
    public function update(User $user, Post $post): bool
    {
        return $user->id === $post->user_id;
    }
    
    public function delete(User $user, Post $post): bool
    {
        return $user->id === $post->user_id || $user->isAdmin();
    }
}

// Register in AuthServiceProvider
protected $policies = [
    Post::class => PostPolicy::class,
];

// Usage in Controller
public function update(Request $request, Post $post)
{
    $this->authorize('update', $post);
    
    $post->update($request->validated());
    
    return response()->json($post);
}

// Usage in Nova Resource
public static function authorizedToUpdate(NovaRequest $request)
{
    return $request->user()->can('update', $request->findModelOrFail());
}
```

## API Development

### Resource Transformers

```php
<?php

namespace App\Http\Resources;

use Illuminate\Http\Resources\Json\JsonResource;

class UserResource extends JsonResource
{
    public function toArray($request)
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'email' => $this->email,
            'role' => $this->role,
            'team' => new TeamResource($this->whenLoaded('team')),
            'posts_count' => $this->when($this->posts_count !== null, $this->posts_count),
            'created_at' => $this->created_at->toIso8601String(),
        ];
    }
}

// Usage
return UserResource::collection(User::with('team')->paginate());
```

### Request Validation

```php
<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreUserRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user()->can('create', User::class);
    }
    
    public function rules(): array
    {
        return [
            'name' => ['required', 'string', 'max:255'],
            'email' => ['required', 'email', Rule::unique('users')],
            'password' => ['required', 'string', 'min:8', 'confirmed'],
            'role' => ['required', Rule::in(['admin', 'editor', 'viewer'])],
        ];
    }
    
    public function messages(): array
    {
        return [
            'email.unique' => 'This email is already registered.',
            'password.confirmed' => 'The password confirmation does not match.',
        ];
    }
}
```

## Performance Optimization

### Query Optimization Checklist
1. Use `select()` to fetch only needed columns
2. Use `with()` for eager loading relationships
3. Use `withCount()` instead of counting in loop
4. Use `chunk()` for large datasets
5. Use database indexes on filtered/sorted columns
6. Use `whereHas()` efficiently (avoid subqueries when possible)
7. Cache expensive queries

### Caching Strategy

```php
use Illuminate\Support\Facades\Cache;

// Cache forever (until manually cleared)
$value = Cache::rememberForever('key', function () {
    return DB::table('users')->count();
});

// Cache with TTL
$users = Cache::remember('active-users', 3600, function () {
    return User::active()->get();
});

// Cache with tags (Redis/Memcached only)
Cache::tags(['users', 'active'])->put('active-users', $users, 3600);
Cache::tags(['users'])->flush(); // Clear all user-related cache

// Nova-specific: Cache permissions
public static function authorizedToViewAny(NovaRequest $request): bool
{
    return Cache::remember(
        "nova-auth-{$request->user()->id}",
        3600,
        fn() => $request->user()->can('viewAny', static::$model)
    );
}
```

## Testing

### Feature Tests

```php
<?php

namespace Tests\Feature;

use Tests\TestCase;
use App\Models\User;

class UserTest extends TestCase
{
    public function test_user_can_be_created()
    {
        $this->actingAs(User::factory()->admin()->create());
        
        $response = $this->postJson('/api/users', [
            'name' => 'John Doe',
            'email' => 'john@example.com',
            'password' => 'password',
            'password_confirmation' => 'password',
        ]);
        
        $response->assertStatus(201);
        $this->assertDatabaseHas('users', ['email' => 'john@example.com']);
    }
}
```

## Common Patterns

### Repository Pattern (When Needed)

```php
<?php

namespace App\Repositories;

interface UserRepositoryInterface
{
    public function find(int $id): ?User;
    public function create(array $data): User;
    public function update(User $user, array $data): User;
}

class UserRepository implements UserRepositoryInterface
{
    public function find(int $id): ?User
    {
        return User::find($id);
    }
    
    public function create(array $data): User
    {
        return User::create($data);
    }
    
    public function update(User $user, array $data): User
    {
        $user->update($data);
        return $user;
    }
}
```

**Note:** Only use Repository pattern when you need to:
- Abstract database implementation
- Support multiple data sources
- Complex query logic reused across app
- For simple CRUD, Eloquent is sufficient

## Error Handling

```php
// Controller
public function show($id)
{
    try {
        $user = User::findOrFail($id);
        return new UserResource($user);
    } catch (ModelNotFoundException $e) {
        return response()->json(['message' => 'User not found'], 404);
    }
}

// Global Exception Handler (app/Exceptions/Handler.php)
public function render($request, Throwable $exception)
{
    if ($exception instanceof ModelNotFoundException) {
        return response()->json(['message' => 'Resource not found'], 404);
    }
    
    return parent::render($request, $exception);
}
```

## Deployment Checklist

- [ ] Run `php artisan config:cache`
- [ ] Run `php artisan route:cache`
- [ ] Run `php artisan view:cache`
- [ ] Set `APP_DEBUG=false`
- [ ] Set up queue workers
- [ ] Configure proper logging
- [ ] Set up scheduled tasks (cron)
- [ ] Run migrations
- [ ] Seed required data
- [ ] Test error pages (500, 404)
