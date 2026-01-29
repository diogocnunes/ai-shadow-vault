---
name: laravel-code-quality
description: Expert guidance for writing high-quality PHP/Laravel code that passes static analysis and code quality tools. Use when writing, reviewing, or fixing code to comply with Larastan (PHPStan), PHPMND (magic number detection), Rector (automated refactoring), and Laravel Pint (code style). Covers type safety, avoiding magic numbers, modern PHP patterns, PSR-12 compliance, and automated code improvements.
---

# Laravel Code Quality Expert

Expert guidance for writing clean, type-safe, maintainable PHP/Laravel code that passes all static analysis and quality tools.

## Quality Tools Overview

**Larastan (PHPStan)**: Static analysis for type safety and bug detection
**PHPMND**: Detects magic numbers that should be constants
**Rector**: Automated refactoring and modernization
**Laravel Pint**: Code style formatter (PSR-12 + Laravel conventions)

## Larastan (PHPStan) - Level 9 Compliance

### Type Declaration Rules

**Always declare types** for parameters, return types, and properties:

```php
// ❌ Bad - No types
class PostService
{
    public function create($data)
    {
        return Post::create($data);
    }
}

// ✅ Good - Full type declarations
class PostService
{
    public function create(array $data): Post
    {
        return Post::create($data);
    }
}

// ✅ Better - Use DTOs
class PostService
{
    public function create(CreatePostData $data): Post
    {
        return Post::create($data->toArray());
    }
}
```

### Property Types (PHP 8.1+)

```php
// ❌ Bad - No property types
class Post extends Model
{
    protected $fillable = ['title', 'content'];
}

// ✅ Good - Typed properties with defaults
class Post extends Model
{
    protected $fillable = ['title', 'content', 'status', 'published_at'];
    
    protected $casts = [
        'published_at' => 'datetime',
        'is_featured' => 'boolean',
    ];
    
    // Relationships should have return types
    public function author(): BelongsTo
    {
        return $this->belongsTo(User::class, 'author_id');
    }
    
    public function comments(): HasMany
    {
        return $this->hasMany(Comment::class);
    }
    
    public function tags(): BelongsToMany
    {
        return $this->belongsToMany(Tag::class);
    }
}

// ✅ Best - Use typed attributes (Laravel 11+)
class Post extends Model
{
    protected function title(): Attribute
    {
        return Attribute::make(
            get: fn (string $value): string => ucfirst($value),
            set: fn (string $value): string => strtolower($value),
        );
    }
}
```

### Collections and Generics

```php
// ❌ Bad - Generic collection
public function getPosts(): Collection
{
    return Post::all();
}

// ✅ Good - Specify collection type with PHPDoc
/**
 * @return Collection<int, Post>
 */
public function getPosts(): Collection
{
    return Post::all();
}

// ✅ Better - Use specific collection classes
/**
 * @return \Illuminate\Database\Eloquent\Collection<int, Post>
 */
public function getPosts(): \Illuminate\Database\Eloquent\Collection
{
    return Post::all();
}
```

### Nullable Types and Null Safety

```php
// ❌ Bad - Potential null issues
public function getAuthorName(Post $post): string
{
    return $post->author->name;
}

// ✅ Good - Handle nulls explicitly
public function getAuthorName(Post $post): string
{
    return $post->author?->name ?? 'Unknown Author';
}

// ✅ Better - Use null return type when appropriate
public function getAuthorName(Post $post): ?string
{
    return $post->author?->name;
}

// ✅ Best - Type-safe with early returns
public function getAuthorName(Post $post): string
{
    if ($post->author === null) {
        return 'Unknown Author';
    }
    
    return $post->author->name;
}
```

### Array Shapes (PHPDoc)

```php
// ❌ Bad - Untyped array
public function getPostData(Post $post): array
{
    return [
        'id' => $post->id,
        'title' => $post->title,
        'author' => $post->author->name,
    ];
}

// ✅ Good - Document array shape
/**
 * @return array{id: int, title: string, author: string}
 */
public function getPostData(Post $post): array
{
    return [
        'id' => $post->id,
        'title' => $post->title,
        'author' => $post->author->name,
    ];
}

// ✅ Better - Use typed class/DTO
class PostData
{
    public function __construct(
        public readonly int $id,
        public readonly string $title,
        public readonly string $author,
    ) {}
    
    public static function fromModel(Post $post): self
    {
        return new self(
            id: $post->id,
            title: $post->title,
            author: $post->author->name,
        );
    }
}
```

### Enums (PHP 8.1+)

```php
// ❌ Bad - Magic strings
public function updateStatus(Post $post, string $status): void
{
    $post->update(['status' => $status]);
}

// ✅ Good - Use enums
enum PostStatus: string
{
    case DRAFT = 'draft';
    case REVIEWING = 'reviewing';
    case PUBLISHED = 'published';
    case ARCHIVED = 'archived';
    
    public function label(): string
    {
        return match($this) {
            self::DRAFT => 'Draft',
            self::REVIEWING => 'Under Review',
            self::PUBLISHED => 'Published',
            self::ARCHIVED => 'Archived',
        };
    }
    
    public function color(): string
    {
        return match($this) {
            self::DRAFT => 'gray',
            self::REVIEWING => 'warning',
            self::PUBLISHED => 'success',
            self::ARCHIVED => 'danger',
        };
    }
}

class Post extends Model
{
    protected $casts = [
        'status' => PostStatus::class,
    ];
}

public function updateStatus(Post $post, PostStatus $status): void
{
    $post->update(['status' => $status]);
}
```

### Generic Methods

```php
// ❌ Bad - No type info
public function findById($id)
{
    return Post::find($id);
}

// ✅ Good - Specific types
public function findById(int $id): ?Post
{
    return Post::find($id);
}

// ✅ Better - Use generic pattern
/**
 * @template T of Model
 * @param class-string<T> $model
 * @return T|null
 */
public function findById(string $model, int $id): ?Model
{
    return $model::find($id);
}
```

### Larastan Configuration

```neon
# phpstan.neon
includes:
    - vendor/larastan/larastan/extension.neon

parameters:
    paths:
        - app
        - config
        - routes
    
    level: 9
    
    excludePaths:
        - app/Console/Kernel.php
    
    checkMissingIterableValueType: false
    checkGenericClassInNonGenericObjectType: false
    
    ignoreErrors:
        - '#PHPDoc tag @var#'
```

## PHPMND - Magic Number Detection

### Constants for Magic Numbers

```php
// ❌ Bad - Magic numbers
public function calculateDiscount(float $price): float
{
    if ($price > 100) {
        return $price * 0.15;
    }
    
    return $price * 0.10;
}

public function getPaginatedPosts()
{
    return Post::paginate(20);
}

// ✅ Good - Named constants
class DiscountCalculator
{
    private const MINIMUM_PRICE_FOR_PREMIUM_DISCOUNT = 100.0;
    private const PREMIUM_DISCOUNT_RATE = 0.15;
    private const STANDARD_DISCOUNT_RATE = 0.10;
    
    public function calculateDiscount(float $price): float
    {
        if ($price > self::MINIMUM_PRICE_FOR_PREMIUM_DISCOUNT) {
            return $price * self::PREMIUM_DISCOUNT_RATE;
        }
        
        return $price * self::STANDARD_DISCOUNT_RATE;
    }
}

class PostController extends Controller
{
    private const POSTS_PER_PAGE = 20;
    
    public function index()
    {
        return Post::paginate(self::POSTS_PER_PAGE);
    }
}
```

### Configuration Constants

```php
// ❌ Bad - Hardcoded values
public function sendEmail(User $user): void
{
    Mail::to($user)->send(new WelcomeEmail($user));
    
    sleep(2); // Rate limiting
}

// ✅ Good - Use config
// config/mail.php
return [
    'rate_limit_delay_seconds' => 2,
    'welcome_email_enabled' => true,
];

public function sendEmail(User $user): void
{
    if (! config('mail.welcome_email_enabled')) {
        return;
    }
    
    Mail::to($user)->send(new WelcomeEmail($user));
    
    sleep(config('mail.rate_limit_delay_seconds'));
}

// ✅ Better - Use service with injected config
class EmailService
{
    public function __construct(
        private readonly int $rateLimitDelay,
        private readonly bool $welcomeEmailEnabled,
    ) {}
    
    public function sendWelcomeEmail(User $user): void
    {
        if (! $this->welcomeEmailEnabled) {
            return;
        }
        
        Mail::to($user)->send(new WelcomeEmail($user));
        
        sleep($this->rateLimitDelay);
    }
}
```

### Acceptable Numbers (PHPMND Ignore List)

Some numbers are universally understood and don't need constants:
- `0`, `1`, `2` in array operations
- HTTP status codes (200, 404, etc.)
- Percentages in calculations when context is clear
- Database transaction isolation levels

```php
// phpmd.xml
<?xml version="1.0"?>
<phpmd>
    <rule ref="rulesets/codesize.xml"/>
    <rule ref="rulesets/controversial.xml"/>
    <rule ref="rulesets/design.xml"/>
    <rule ref="rulesets/naming.xml"/>
    <rule ref="rulesets/unusedcode.xml"/>
</phpmd>

<!-- .phpmnd.php -->
<?php

return [
    'excludes' => [
        'tests',
        'vendor',
    ],
    'exclude-paths' => [
        'tests',
        'database/migrations',
    ],
    'ignore-numbers' => [0, 1, 2],
    'ignore-strings' => ['0', '1', '2'],
    'extensions' => ['php'],
];
```

## Rector - Automated Refactoring

### PHP 8.1+ Modernization

```php
// ❌ Old - PHP 7.4 style
class PostController extends Controller
{
    private UserRepository $users;
    private PostRepository $posts;
    
    public function __construct(UserRepository $users, PostRepository $posts)
    {
        $this->users = $users;
        $this->posts = $posts;
    }
}

// ✅ New - PHP 8.1 constructor property promotion
class PostController extends Controller
{
    public function __construct(
        private readonly UserRepository $users,
        private readonly PostRepository $posts,
    ) {}
}

// ❌ Old - isset() checks
if (isset($data['title']) && $data['title'] !== null) {
    $post->title = $data['title'];
}

// ✅ New - Null coalescing
$post->title = $data['title'] ?? $post->title;

// ✅ Better - Null safe operator
$authorName = $post?->author?->name ?? 'Unknown';
```

### Array to Match Expression

```php
// ❌ Old - Complex if/elseif
public function getStatusLabel(string $status): string
{
    if ($status === 'draft') {
        return 'Draft';
    } elseif ($status === 'published') {
        return 'Published';
    } elseif ($status === 'archived') {
        return 'Archived';
    }
    
    return 'Unknown';
}

// ✅ New - Match expression
public function getStatusLabel(PostStatus $status): string
{
    return match($status) {
        PostStatus::DRAFT => 'Draft',
        PostStatus::PUBLISHED => 'Published',
        PostStatus::ARCHIVED => 'Archived',
    };
}
```

### Named Arguments

```php
// ❌ Old - Positional arguments (unclear)
Post::create([
    'title' => $title,
    'content' => $content,
    'author_id' => $authorId,
    'published_at' => $publishedAt,
    'is_featured' => $isFeatured,
]);

// ✅ New - Named arguments (clear intent)
$this->createPost(
    title: $title,
    content: $content,
    authorId: $authorId,
    publishedAt: $publishedAt,
    isFeatured: $isFeatured,
);
```

### Strict Types

```php
// ✅ Always declare strict types at the top of every file
<?php

declare(strict_types=1);

namespace App\Services;

use App\Models\Post;
```

### Rector Configuration

```php
// rector.php
<?php

declare(strict_types=1);

use Rector\Config\RectorConfig;
use Rector\Set\ValueObject\LevelSetList;
use Rector\Set\ValueObject\SetList;
use RectorLaravel\Set\LaravelSetList;

return RectorConfig::configure()
    ->withPaths([
        __DIR__ . '/app',
        __DIR__ . '/config',
        __DIR__ . '/routes',
        __DIR__ . '/tests',
    ])
    ->withSkip([
        __DIR__ . '/bootstrap',
        __DIR__ . '/storage',
        __DIR__ . '/vendor',
    ])
    ->withPhpSets(php81: true)
    ->withSets([
        LevelSetList::UP_TO_PHP_81,
        SetList::CODE_QUALITY,
        SetList::CODING_STYLE,
        SetList::TYPE_DECLARATION,
        SetList::PRIVATIZATION,
        SetList::EARLY_RETURN,
        LaravelSetList::LARAVEL_100,
        LaravelSetList::LARAVEL_CODE_QUALITY,
        LaravelSetList::LARAVEL_ARRAY_STR_FUNCTION_TO_STATIC_CALL,
    ])
    ->withTypeCoverageLevel(0);
```

## Laravel Pint - Code Style

### PSR-12 + Laravel Conventions

Laravel Pint automatically formats code. Key patterns to follow:

```php
// ✅ Class structure order
class PostController extends Controller
{
    // 1. Use statements (traits)
    use AuthorizesRequests;
    
    // 2. Constants
    private const POSTS_PER_PAGE = 20;
    
    // 3. Properties
    private bool $cacheEnabled = true;
    
    // 4. Constructor
    public function __construct(
        private readonly PostRepository $posts,
    ) {}
    
    // 5. Public methods
    public function index(): View
    {
        return view('posts.index');
    }
    
    // 6. Protected methods
    protected function loadPosts(): Collection
    {
        return $this->posts->all();
    }
    
    // 7. Private methods
    private function cacheKey(): string
    {
        return 'posts.all';
    }
}
```

### Method Chaining

```php
// ✅ Good - Readable chaining
$posts = Post::query()
    ->where('status', PostStatus::PUBLISHED)
    ->where('published_at', '<=', now())
    ->with(['author', 'categories'])
    ->orderBy('published_at', 'desc')
    ->paginate(20);

// ✅ Good - Array formatting
$data = [
    'title' => $request->title,
    'content' => $request->content,
    'status' => PostStatus::DRAFT,
    'author_id' => auth()->id(),
];
```

### Control Structures

```php
// ✅ Good - Early returns
public function update(Request $request, Post $post): RedirectResponse
{
    if (! $post->isEditable()) {
        return redirect()->back()->with('error', 'Post cannot be edited');
    }
    
    if ($post->author_id !== auth()->id() && ! auth()->user()->isAdmin()) {
        abort(403);
    }
    
    $post->update($request->validated());
    
    return redirect()->route('posts.show', $post);
}

// ✅ Good - Guard clauses
public function publish(Post $post): void
{
    if ($post->status === PostStatus::PUBLISHED) {
        return;
    }
    
    if (! $post->isComplete()) {
        throw new InvalidStateException('Post is incomplete');
    }
    
    $post->update([
        'status' => PostStatus::PUBLISHED,
        'published_at' => now(),
    ]);
}
```

### Pint Configuration

```json
// pint.json
{
    "preset": "laravel",
    "rules": {
        "array_syntax": {
            "syntax": "short"
        },
        "binary_operator_spaces": {
            "default": "single_space"
        },
        "blank_line_after_namespace": true,
        "blank_line_after_opening_tag": true,
        "blank_line_before_statement": {
            "statements": ["return"]
        },
        "braces": {
            "allow_single_line_closure": true
        },
        "concat_space": {
            "spacing": "one"
        },
        "declare_strict_types": true,
        "method_chaining_indentation": true,
        "new_with_braces": true,
        "no_unused_imports": true,
        "ordered_imports": {
            "sort_algorithm": "alpha"
        },
        "phpdoc_align": {
            "align": "vertical"
        },
        "trailing_comma_in_multiline": true
    }
}
```

## Complete Example - Quality Compliant Code

```php
<?php

declare(strict_types=1);

namespace App\Services;

use App\Data\CreatePostData;
use App\Enums\PostStatus;
use App\Events\PostPublished;
use App\Models\Post;
use App\Repositories\PostRepository;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;

final class PostService
{
    private const CACHE_TTL_SECONDS = 3600;
    private const SLUG_MAX_LENGTH = 255;
    
    public function __construct(
        private readonly PostRepository $repository,
    ) {}
    
    /**
     * @return \Illuminate\Database\Eloquent\Collection<int, Post>
     */
    public function getPublishedPosts(): \Illuminate\Database\Eloquent\Collection
    {
        return Cache::remember(
            key: 'posts.published',
            ttl: self::CACHE_TTL_SECONDS,
            callback: fn () => $this->repository->getPublished(),
        );
    }
    
    public function create(CreatePostData $data): Post
    {
        return DB::transaction(function () use ($data): Post {
            $post = Post::create([
                'title' => $data->title,
                'slug' => $this->generateSlug($data->title),
                'content' => $data->content,
                'status' => PostStatus::DRAFT,
                'author_id' => $data->authorId,
            ]);
            
            if ($data->categoryIds !== null && count($data->categoryIds) > 0) {
                $post->categories()->sync($data->categoryIds);
            }
            
            return $post->load('categories');
        });
    }
    
    public function publish(Post $post): void
    {
        if ($post->status === PostStatus::PUBLISHED) {
            return;
        }
        
        if (! $this->isPublishable($post)) {
            throw new \InvalidArgumentException('Post is not ready for publication');
        }
        
        $post->update([
            'status' => PostStatus::PUBLISHED,
            'published_at' => now(),
        ]);
        
        Cache::forget('posts.published');
        
        event(new PostPublished($post));
    }
    
    private function isPublishable(Post $post): bool
    {
        return $post->title !== null
            && $post->content !== null
            && $post->author_id !== null
            && strlen($post->content) > 0;
    }
    
    private function generateSlug(string $title): string
    {
        $slug = \Illuminate\Support\Str::slug($title);
        
        if (strlen($slug) > self::SLUG_MAX_LENGTH) {
            $slug = substr($slug, 0, self::SLUG_MAX_LENGTH);
        }
        
        return $this->ensureUniqueSlug($slug);
    }
    
    private function ensureUniqueSlug(string $slug): string
    {
        $originalSlug = $slug;
        $counter = 1;
        
        while (Post::where('slug', $slug)->exists()) {
            $slug = $originalSlug . '-' . $counter;
            $counter++;
        }
        
        return $slug;
    }
}
```

## Integration with GrumPHP

```yaml
# grumphp.yml
grumphp:
    tasks:
        phpstan:
            level: 9
            configuration: phpstan.neon
            use_grumphp_paths: false
            memory_limit: "1024M"
        
        phpmnd:
            directory: ['app', 'src']
            exclude: ['tests']
            exclude_name: []
            exclude_path: []
            extensions: ['php']
            hint: true
            non_zero_exit_on_violation: true
            suffixes: ['Fixer.php']
        
        rector:
            config: rector.php
            dry_run: true
            autoload_file: vendor/autoload.php
        
        pint:
            config: pint.json
            preset: laravel
            test: true
    
    testsuites:
        git_pre_commit:
            tasks:
                - phpstan
                - pint
        
        git_pre_push:
            tasks:
                - phpstan
                - phpmnd
                - rector
                - pint
```

## Common Patterns

### Repository Pattern

```php
<?php

declare(strict_types=1);

namespace App\Repositories;

use App\Enums\PostStatus;
use App\Models\Post;
use Illuminate\Database\Eloquent\Collection;

final class PostRepository
{
    /**
     * @return Collection<int, Post>
     */
    public function getPublished(): Collection
    {
        return Post::query()
            ->where('status', PostStatus::PUBLISHED)
            ->where('published_at', '<=', now())
            ->with(['author', 'categories'])
            ->orderBy('published_at', 'desc')
            ->get();
    }
    
    public function findBySlug(string $slug): ?Post
    {
        return Post::query()
            ->where('slug', $slug)
            ->with(['author', 'categories', 'comments'])
            ->first();
    }
}
```

### Data Transfer Objects

```php
<?php

declare(strict_types=1);

namespace App\Data;

use Illuminate\Http\Request;

final readonly class CreatePostData
{
    /**
     * @param array<int>|null $categoryIds
     */
    public function __construct(
        public string $title,
        public string $content,
        public int $authorId,
        public ?array $categoryIds = null,
    ) {}
    
    public static function fromRequest(Request $request): self
    {
        return new self(
            title: $request->string('title')->toString(),
            content: $request->string('content')->toString(),
            authorId: $request->integer('author_id'),
            categoryIds: $request->has('category_ids')
                ? $request->collect('category_ids')->map(fn ($id) => (int) $id)->toArray()
                : null,
        );
    }
    
    /**
     * @return array<string, mixed>
     */
    public function toArray(): array
    {
        return [
            'title' => $this->title,
            'content' => $this->content,
            'author_id' => $this->authorId,
        ];
    }
}
```

### Action Classes

```php
<?php

declare(strict_types=1);

namespace App\Actions;

use App\Enums\PostStatus;
use App\Events\PostPublished;
use App\Models\Post;
use Illuminate\Support\Facades\Cache;

final class PublishPostAction
{
    private const CACHE_KEY_PREFIX = 'posts.published';
    
    public function execute(Post $post): void
    {
        if ($post->status === PostStatus::PUBLISHED) {
            return;
        }
        
        $post->update([
            'status' => PostStatus::PUBLISHED,
            'published_at' => now(),
        ]);
        
        Cache::forget(self::CACHE_KEY_PREFIX);
        
        event(new PostPublished($post));
    }
}
```

## Testing with Quality Standards

```php
<?php

declare(strict_types=1);

namespace Tests\Feature;

use App\Enums\PostStatus;
use App\Models\Post;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

final class PostTest extends TestCase
{
    use RefreshDatabase;
    
    public function test_can_create_post(): void
    {
        $user = User::factory()->create();
        
        $response = $this->actingAs($user)->post('/posts', [
            'title' => 'Test Post',
            'content' => 'Test content',
        ]);
        
        $response->assertRedirect();
        
        $this->assertDatabaseHas('posts', [
            'title' => 'Test Post',
            'status' => PostStatus::DRAFT->value,
            'author_id' => $user->id,
        ]);
    }
    
    public function test_published_post_appears_in_list(): void
    {
        $post = Post::factory()->published()->create();
        
        $response = $this->get('/posts');
        
        $response->assertSee($post->title);
    }
}
```

## Troubleshooting

**Larastan Issues**:
- Add PHPDoc when generics are unclear
- Use `@phpstan-ignore-next-line` sparingly for known issues
- Configure baseline for legacy code: `vendor/bin/phpstan analyse --generate-baseline`

**PHPMND False Positives**:
- Add to ignore list: `0`, `1`, `2`, `100`, `200`, `404`
- Use constants for business logic numbers
- Config values for operational numbers

**Rector Breaking Changes**:
- Run with `--dry-run` first
- Review changes before committing
- Test thoroughly after automated refactoring

**Pint Conflicts**:
- Run `vendor/bin/pint --test` before committing
- Configure editor to run Pint on save
- Add to pre-commit hooks

## CI/CD Integration

```yaml
# .github/workflows/code-quality.yml
name: Code Quality

on: [push, pull_request]

jobs:
  quality:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup PHP
        uses: shivammathur/setup-php@v2
        with:
          php-version: 8.1
      
      - name: Install dependencies
        run: composer install
      
      - name: Run Pint
        run: vendor/bin/pint --test
      
      - name: Run Larastan
        run: vendor/bin/phpstan analyse
      
      - name: Run PHPMND
        run: vendor/bin/phpmnd app
      
      - name: Run Rector (dry-run)
        run: vendor/bin/rector process --dry-run
```

## Quick Reference

```bash
# Run all quality checks
composer check

# Format code
vendor/bin/pint

# Check code style (no changes)
vendor/bin/pint --test

# Run static analysis
vendor/bin/phpstan analyse

# Check for magic numbers
vendor/bin/phpmnd app

# Run automated refactoring (dry-run)
vendor/bin/rector process --dry-run

# Apply Rector changes
vendor/bin/rector process

# Run GrumPHP
vendor/bin/grumphp run
```

## Composer Scripts

```json
{
    "scripts": {
        "check": [
            "@pint:check",
            "@phpstan",
            "@phpmnd",
            "@rector:check"
        ],
        "fix": [
            "@pint",
            "@rector"
        ],
        "pint": "vendor/bin/pint",
        "pint:check": "vendor/bin/pint --test",
        "phpstan": "vendor/bin/phpstan analyse",
        "phpmnd": "vendor/bin/phpmnd app",
        "rector": "vendor/bin/rector process",
        "rector:check": "vendor/bin/rector process --dry-run"
    }
}
```
