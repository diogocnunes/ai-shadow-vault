---
name: security-performance
description: Security hardening and performance optimization for Laravel + Nova applications. Use when implementing authentication, authorization, input validation, SQL injection prevention, XSS protection, CSRF protection, rate limiting, or when optimizing database queries, caching strategies, reducing N+1 queries, profiling performance bottlenecks, or improving Nova Resource performance. Covers both security threats and performance issues.
---

# Security & Performance

Combined expertise in securing and optimizing Laravel + Nova applications.

## Why Combined?

Security and performance often intersect:
- N+1 queries are both a performance and potential DoS vulnerability
- Rate limiting prevents both abuse and overload
- Query optimization reduces attack surface
- Proper indexing improves both speed and security

## Security Fundamentals

### OWASP Top 10 for Laravel

#### 1. SQL Injection Prevention

```php
// ❌ VULNERABLE - Never do this
$email = request('email');
$user = DB::select("SELECT * FROM users WHERE email = '{$email}'");

// ❌ VULNERABLE - String concatenation
$user = DB::table('users')->whereRaw("email = '{$email}'")->first();

// ✅ SAFE - Parameter binding
$user = DB::select('SELECT * FROM users WHERE email = ?', [$email]);

// ✅ BETTER - Query Builder (auto-escapes)
$user = DB::table('users')->where('email', $email)->first();

// ✅ BEST - Eloquent
$user = User::where('email', $email)->first();
```

#### 2. XSS (Cross-Site Scripting) Prevention

```php
// Blade templates auto-escape by default
{{ $user->name }} // ✅ SAFE - Escaped

{!! $user->bio !!} // ❌ VULNERABLE - Unescaped, use only for trusted HTML

// API responses - ensure proper Content-Type
return response()->json($data); // ✅ SAFE

// Sanitize user input for HTML storage
use Illuminate\Support\Str;
$clean = Str::of($input)->stripTags()->trim();

// Or use HTML Purifier for rich text
composer require mews/purifier
$clean = clean($input);
```

#### 3. CSRF Protection

```php
// Laravel handles CSRF automatically for web routes
// Ensure VerifyCsrfToken middleware is active

// In forms
<form method="POST">
    @csrf
    <!-- form fields -->
</form>

// For AJAX (already in Laravel's default setup)
// resources/js/bootstrap.js includes:
axios.defaults.headers.common['X-CSRF-TOKEN'] = token;

// API routes (use Sanctum token instead)
Route::middleware('auth:sanctum')->post('/api/users', [UserController::class, 'store']);
```

#### 4. Authentication & Authorization

```php
// Strong password hashing (bcrypt default, argon2 available)
use Illuminate\Support\Facades\Hash;

$user->password = Hash::make($password);

if (Hash::check($password, $user->password)) {
    // Password correct
}

// Authorization with Policies
// app/Policies/PostPolicy.php
public function update(User $user, Post $post): bool
{
    return $user->id === $post->user_id;
}

// Usage
$this->authorize('update', $post);

// Nova authorization
public static function authorizedToUpdate(NovaRequest $request): bool
{
    return $request->user()->can('update', $request->findModelOrFail());
}
```

#### 5. Mass Assignment Protection

```php
// Model protection
class User extends Model
{
    // Option 1: Whitelist (recommended)
    protected $fillable = ['name', 'email', 'password'];

    // Option 2: Blacklist (use carefully)
    protected $guarded = ['id', 'is_admin', 'role'];
}

// Request validation
public function rules(): array
{
    return [
        'name' => 'required|string|max:255',
        'email' => 'required|email|unique:users',
        // Only allow specific fields
    ];
}

// Never do this:
User::create($request->all()); // ❌ DANGEROUS

// Do this:
User::create($request->validated()); // ✅ SAFE
```

#### 6. Insecure Direct Object References (IDOR)

```php
// ❌ VULNERABLE
public function show($id)
{
    $document = Document::findOrFail($id);
    return view('document', compact('document'));
}

// ✅ SAFE - Always check ownership
public function show($id)
{
    $document = Document::where('id', $id)
        ->where('user_id', auth()->id())
        ->firstOrFail();

    return view('document', compact('document'));
}

// ✅ BETTER - Use Policy
public function show(Document $document)
{
    $this->authorize('view', $document);
    return view('document', compact('document'));
}

// Nova - Scope indexQuery
public static function indexQuery(NovaRequest $request, $query)
{
    return $query->where('user_id', $request->user()->id);
}
```

#### 7. Security Misconfiguration

```php
// .env - Production settings
APP_ENV=production
APP_DEBUG=false // ❌ NEVER true in production
APP_KEY=<generated-key> // php artisan key:generate

// Disable directory listing
// public/.htaccess should have: Options -Indexes

// Hide sensitive headers
// config/session.php
'secure' => env('SESSION_SECURE_COOKIE', true), // HTTPS only
'http_only' => true, // Prevent JavaScript access
'same_site' => 'lax', // CSRF protection

// Rate limiting
// app/Http/Kernel.php
'api' => [
    'throttle:60,1', // 60 requests per minute
],
```

#### 8. Sensitive Data Exposure

```php
// Hide sensitive fields from JSON
class User extends Model
{
    protected $hidden = [
        'password',
        'remember_token',
        'two_factor_secret',
    ];
}

// Don't log sensitive data
Log::info('User login', [
    'email' => $user->email,
    // ❌ 'password' => $password, // Never log passwords
]);

// Encrypt sensitive database columns
protected $casts = [
    'ssn' => 'encrypted',
    'credit_card' => 'encrypted',
];
```

### Security Headers

```php
// app/Http/Middleware/SecurityHeaders.php
public function handle(Request $request, Closure $next)
{
    $response = $next($request);

    $response->headers->set('X-Content-Type-Options', 'nosniff');
    $response->headers->set('X-Frame-Options', 'DENY');
    $response->headers->set('X-XSS-Protection', '1; mode=block');
    $response->headers->set('Referrer-Policy', 'strict-origin-when-cross-origin');
    $response->headers->set('Permissions-Policy', 'geolocation=(), microphone=(), camera=()');

    // CSP (adjust for your needs)
    $response->headers->set('Content-Security-Policy', 
        "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'"
    );

    return $response;
}
```

### Rate Limiting

```php
// config/fortify.php or custom middleware
use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Support\Facades\RateLimiter;

RateLimiter::for('login', function (Request $request) {
    return Limit::perMinute(5)->by($request->ip());
});

RateLimiter::for('api', function (Request $request) {
    return Limit::perMinute(60)->by($request->user()?->id ?: $request->ip());
});

// Usage in routes
Route::middleware(['throttle:login'])->post('/login', [AuthController::class, 'login']);
Route::middleware(['throttle:api'])->group(function () {
    // API routes
});
```

### API Token Security (Sanctum)

```php
// Issue tokens with specific abilities
$token = $user->createToken('api-token', ['read', 'write'])->plainTextToken;

// Check abilities in controller
if ($request->user()->tokenCan('write')) {
    // Allow write operations
}

// Revoke tokens
$user->tokens()->delete(); // All tokens
$user->currentAccessToken()->delete(); // Current token only

// Token expiration (config/sanctum.php)
'expiration' => 60, // Minutes
```

## Performance Optimization

### Query Optimization

#### N+1 Query Prevention

```php
// ❌ BAD - N+1 queries (1 query + N queries for users)
$posts = Post::all();
foreach ($posts as $post) {
    echo $post->user->name; // Queries for each post
}

// ✅ GOOD - Eager loading (2 queries total)
$posts = Post::with('user')->get();
foreach ($posts as $post) {
    echo $post->user->name; // No extra query
}

// ✅ BETTER - Select only needed columns
$posts = Post::select('id', 'title', 'user_id')
    ->with('user:id,name')
    ->get();

// ✅ BEST - With counts (1 query with subquery)
$posts = Post::withCount('comments')->get();
foreach ($posts as $post) {
    echo $post->comments_count; // No query
}
```

#### Nova Resource Optimization

```php
class Post extends Resource
{
    // Always eager load relationships
    public static function indexQuery(NovaRequest $request, $query)
    {
        return $query->with(['user', 'category']);
    }

    // For relatableQuery (dropdowns, relationships)
    public static function relatableUsers(NovaRequest $request, $query)
    {
        return $query->select('id', 'name'); // Only needed columns
    }

    // Optimize counts
    public function fields(NovaRequest $request)
    {
        return [
            // ❌ BAD
            Number::make('Comments', function () {
                return $this->comments()->count(); // Queries every time
            }),

            // ✅ GOOD - Use withCount in indexQuery
            Number::make('Comments', 'comments_count'),
        ];
    }
}
```

### Database Indexing

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

    // Single column indexes
    $table->index('status'); // Frequently filtered
    $table->index('published_at'); // Frequently sorted

    // Composite indexes (order matters!)
    $table->index(['user_id', 'status']); // For queries like WHERE user_id = ? AND status = ?
    $table->index(['status', 'published_at']); // For queries like WHERE status = ? ORDER BY published_at

    // Full-text search
    $table->fullText(['title', 'content']); // MySQL 5.7+, PostgreSQL 10+
});

// When to add indexes:
// - Columns in WHERE clauses
// - Columns in JOIN conditions
// - Columns in ORDER BY
// - Foreign keys (Laravel does this automatically)

// When NOT to add indexes:
// - Small tables (< 1000 rows)
// - Columns with low cardinality (e.g., boolean)
// - Columns rarely queried
```

### Caching Strategies

```php
use Illuminate\Support\Facades\Cache;

// Cache query results
$users = Cache::remember('active-users', 3600, function () {
    return User::where('status', 'active')->get();
});

// Cache with tags (Redis/Memcached only)
Cache::tags(['users', 'active'])->put('active-users', $users, 3600);
Cache::tags(['users'])->flush(); // Clear all user-related cache

// Cache permissions (Nova)
public static function authorizedToViewAny(NovaRequest $request): bool
{
    return Cache::remember(
        "nova-{$request->user()->id}-can-view-" . static::class,
        3600,
        fn() => $request->user()->can('viewAny', static::$model)
    );
}

// Model attribute caching
class User extends Model
{
    public function getFullNameAttribute(): string
    {
        return Cache::remember(
            "user-{$this->id}-full-name",
            3600,
            fn() => "{$this->first_name} {$this->last_name}"
        );
    }
}

// Cache expensive calculations
class Dashboard
{
    public function getStats()
    {
        return Cache::remember('dashboard-stats', 600, function () {
            return [
                'users' => User::count(),
                'posts' => Post::count(),
                'revenue' => Order::sum('total'),
            ];
        });
    }
}
```

### Query Optimization Patterns

```php
// Use cursor() for large datasets (memory efficient)
User::cursor()->each(function ($user) {
    // Process user
});

// Use chunk() for batch processing
User::chunk(100, function ($users) {
    foreach ($users as $user) {
        // Process user
    }
});

// Lazy collections (Laravel 8+)
User::lazy()->each(function ($user) {
    // Process user
});

// Avoid select *
User::select('id', 'name', 'email')->get(); // Only needed columns

// Use exists() instead of count() > 0
if (Post::where('user_id', $userId)->exists()) { // Fast
    // User has posts
}
// Instead of:
if (Post::where('user_id', $userId)->count() > 0) { // Slower

// Subquery optimization
// Instead of two queries:
$users = User::all();
$activeUsers = $users->filter(fn($u) => $u->posts()->where('status', 'published')->exists());

// Use single query with whereHas:
$activeUsers = User::whereHas('posts', function ($query) {
    $query->where('status', 'published');
})->get();
```

### Response Caching

```php
// HTTP Cache headers
public function show(Post $post)
{
    return response()
        ->view('post', compact('post'))
        ->header('Cache-Control', 'public, max-age=3600');
}

// Use Laravel's response cache package
composer require spatie/laravel-responsecache

// Cache entire responses
Route::middleware('cacheResponse')->get('/posts', [PostController::class, 'index']);
```

### Database Connection Optimization

```php
// config/database.php
'mysql' => [
    'read' => [
        'host' => [
            '192.168.1.1', // Read replica 1
            '192.168.1.2', // Read replica 2
        ],
    ],
    'write' => [
        'host' => [
            '192.168.1.3', // Master
        ],
    ],
    'sticky' => true, // Ensure reads after writes go to master
],
```

### Asset Optimization

```bash
# Compile assets for production
npm run build

# Vite automatically:
# - Minifies JS/CSS
# - Tree-shakes unused code
# - Generates hashed filenames
# - Code splits by route

# Laravel Mix (legacy):
npm run production
```

## Performance Monitoring

### Laravel Telescope

```bash
composer require laravel/telescope
php artisan telescope:install
php artisan migrate
```

```php
// Monitor:
// - Slow queries (> 100ms)
// - N+1 queries
// - Failed jobs
// - Exceptions
// - Cache hits/misses
// - HTTP requests

// Disable in production or restrict access
// app/Providers/TelescopeServiceProvider.php
protected function gate()
{
    Gate::define('viewTelescope', function ($user) {
        return in_array($user->email, [
            'admin@example.com',
        ]);
    });
}
```

### Laravel Debugbar (Development Only)

```bash
composer require barryvdh/laravel-debugbar --dev
```

```php
// Shows:
// - Query count and time
// - Memory usage
// - Route information
// - View rendering time

// Never enable in production
```

### Query Logging

```php
// Enable query log
DB::enableQueryLog();

// Your code here
$users = User::with('posts')->get();

// Get executed queries
$queries = DB::getQueryLog();
dd($queries);

// In development, log slow queries
DB::listen(function ($query) {
    if ($query->time > 100) { // > 100ms
        Log::warning('Slow query', [
            'sql' => $query->sql,
            'bindings' => $query->bindings,
            'time' => $query->time,
        ]);
    }
});
```

### APM Tools Integration

```php
// New Relic
composer require newrelic/php-agent

// Scout APM
composer require scoutapp/scout-apm-laravel

// Sentry Performance Monitoring
composer require sentry/sentry-laravel
```

## Security Auditing

### Regular Security Checks

```bash
# Check for known vulnerabilities
composer audit

# Update dependencies
composer update --with-all-dependencies

# Static analysis
composer require --dev phpstan/phpstan
vendor/bin/phpstan analyse app

# Security scanner
composer require --dev enlightn/security-checker
php artisan security:check
```

### Code Review Checklist

- [ ] No raw SQL queries with user input
- [ ] All user input validated
- [ ] CSRF protection enabled
- [ ] XSS prevention (escaped output)
- [ ] Authorization checks on all actions
- [ ] Sensitive data not logged
- [ ] Secure headers configured
- [ ] Rate limiting implemented
- [ ] API tokens properly secured
- [ ] File uploads validated and scanned

## Performance Checklist

- [ ] Eager load relationships
- [ ] Database indexes on filtered columns
- [ ] Cache expensive queries
- [ ] Use queue for long-running tasks
- [ ] Optimize Nova indexQuery
- [ ] Enable OPcache in production
- [ ] Use CDN for assets
- [ ] Enable HTTP/2
- [ ] Compress responses (gzip)
- [ ] Lazy load images

## Production Optimization

```php
// Run in production
php artisan config:cache
php artisan route:cache
php artisan view:cache
php artisan event:cache

// Enable OPcache (php.ini)
opcache.enable=1
opcache.memory_consumption=256
opcache.max_accelerated_files=20000
opcache.validate_timestamps=0 // Disable in production

// Queue workers
php artisan queue:work --tries=3 --timeout=60

// Supervisor config for queue workers
[program:laravel-worker]
process_name=%(program_name)s_%(process_num)02d
command=php /path/to/artisan queue:work --sleep=3 --tries=3 --max-time=3600
autostart=true
autorestart=true
user=www-data
numprocs=4
```

## Load Testing

```bash
# Apache Bench
ab -n 1000 -c 10 http://example.com/

# Siege
siege -c 100 -t 60S http://example.com/

# k6 (modern alternative)
k6 run script.js
```

## Emergency Response

### If Site is Under Attack

1. **Enable maintenance mode**
```bash
php artisan down --refresh=15 --retry=60
```

2. **Increase rate limits temporarily**
```php
RateLimiter::for('api', function (Request $request) {
    return Limit::perMinute(10)->by($request->ip()); // Reduce from 60 to 10
});
```

3. **Block IP addresses** (CloudFlare, nginx, or application level)

4. **Scale infrastructure** (add servers, increase resources)

### If Site is Slow

1. **Check Telescope/logs** for slow queries
2. **Clear all caches** if suspect stale data
3. **Profile with Blackfire/Xdebug** to find bottlenecks
4. **Check database connections** pool exhaustion
5. **Monitor memory usage** for memory leaks
6. **Review recent deployments** for performance regressions

## Best Practices Summary

### Security
✅ Validate all user input
✅ Use parameterized queries
✅ Implement proper authorization
✅ Keep dependencies updated
✅ Enable rate limiting
✅ Use HTTPS everywhere
✅ Don't trust user input

### Performance
✅ Eager load relationships
✅ Index frequently queried columns
✅ Cache expensive operations
✅ Monitor query performance
✅ Use queues for background jobs
✅ Optimize assets
✅ Profile before optimizing
