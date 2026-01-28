---
name: qa-automation
description: Comprehensive testing strategy for Laravel + Vue applications using Pest PHP, PHPUnit, Laravel Dusk, and Playwright. Use when writing unit tests, feature tests, integration tests, browser tests, or API tests. Covers test organization, mocking, database testing, Nova resource testing, and CI/CD integration. Ensures code quality and prevents regressions.
---

# QA Automation

Comprehensive testing guidance for Laravel + Vue applications with focus on Pest PHP and modern testing practices.

## Testing Philosophy

### Testing Pyramid
1. **Unit Tests (70%)** - Fast, isolated, test single functions/methods
2. **Integration Tests (20%)** - Test component interactions
3. **E2E Tests (10%)** - Test complete user flows (expensive, slower)

### Test Coverage Goals
- Critical business logic: 90%+
- Models and Services: 80%+
- Controllers: 70%+
- Overall project: 70%+

## Stack Coverage

### Backend Testing
- Pest PHP (preferred)
- PHPUnit (legacy support)
- Laravel Testing utilities
- Mockery for mocking

### Frontend Testing
- Vitest (Vue 3)
- Vue Test Utils
- Playwright (E2E)
- Laravel Dusk (if needed)

## Pest PHP - Modern Laravel Testing

### Installation & Setup

```bash
composer require pestphp/pest --dev --with-all-dependencies
composer require pestphp/pest-plugin-laravel --dev
php artisan pest:install

# Optional plugins
composer require pestphp/pest-plugin-faker --dev
```

### Basic Test Structure

```php
<?php

use App\Models\User;

test('user can be created', function () {
    $user = User::factory()->create([
        'name' => 'John Doe',
        'email' => 'john@example.com',
    ]);

    expect($user->name)->toBe('John Doe')
        ->and($user->email)->toBe('john@example.com');
});

it('validates user email', function () {
    $response = $this->postJson('/api/users', [
        'name' => 'John Doe',
        'email' => 'invalid-email',
    ]);

    $response->assertStatus(422)
        ->assertJsonValidationErrors(['email']);
});
```

### Advanced Pest Features

```php
<?php

// Higher Order Tests
it('has users')->expect(User::all())->toHaveCount(10);

// Datasets (run same test with different inputs)
test('user validation', function ($email, $isValid) {
    $response = $this->postJson('/api/users', [
        'name' => 'John',
        'email' => $email,
    ]);

    if ($isValid) {
        $response->assertStatus(201);
    } else {
        $response->assertStatus(422);
    }
})->with([
    ['john@example.com', true],
    ['invalid-email', false],
    ['', false],
]);

// Beforehand / Afterhand hooks
beforeEach(function () {
    $this->user = User::factory()->create();
});

afterEach(function () {
    // Cleanup
});

// Test groups
test('admin can delete user', function () {
    // Test code
})->group('admin', 'authorization');

// Run only: php artisan test --group=admin
```

## Unit Testing

### Testing Models

```php
<?php

use App\Models\{User, Post};

test('user has many posts relationship', function () {
    $user = User::factory()->create();
    $posts = Post::factory()->count(3)->create(['user_id' => $user->id]);

    expect($user->posts)->toHaveCount(3)
        ->and($user->posts->first())->toBeInstanceOf(Post::class);
});

test('user full name accessor', function () {
    $user = User::factory()->create([
        'first_name' => 'John',
        'last_name' => 'Doe',
    ]);

    expect($user->full_name)->toBe('John Doe');
});

test('user status scope', function () {
    User::factory()->count(5)->create(['status' => 'active']);
    User::factory()->count(3)->create(['status' => 'inactive']);

    $activeUsers = User::active()->get();

    expect($activeUsers)->toHaveCount(5);
});
```

### Testing Services

```php
<?php

use App\Services\UserService;
use App\Models\User;

test('user service creates user with role', function () {
    $service = new UserService();

    $user = $service->create([
        'name' => 'John Doe',
        'email' => 'john@example.com',
        'password' => 'password',
        'role' => 'editor',
    ]);

    expect($user)->toBeInstanceOf(User::class)
        ->and($user->hasRole('editor'))->toBeTrue();

    $this->assertDatabaseHas('users', [
        'email' => 'john@example.com',
    ]);
});

test('user service handles duplicate email', function () {
    $service = new UserService();
    
    User::factory()->create(['email' => 'john@example.com']);

    $service->create([
        'name' => 'Jane Doe',
        'email' => 'john@example.com',
        'password' => 'password',
    ]);
})->throws(\Illuminate\Database\QueryException::class);
```

## Feature Testing

### Testing Controllers

```php
<?php

use App\Models\User;

test('user can view their profile', function () {
    $user = User::factory()->create();

    $response = $this->actingAs($user)
        ->getJson("/api/users/{$user->id}");

    $response->assertStatus(200)
        ->assertJson([
            'data' => [
                'id' => $user->id,
                'name' => $user->name,
                'email' => $user->email,
            ],
        ]);
});

test('user cannot view another user profile', function () {
    $user = User::factory()->create();
    $otherUser = User::factory()->create();

    $response = $this->actingAs($user)
        ->getJson("/api/users/{$otherUser->id}");

    $response->assertStatus(403);
});

test('guest cannot access user profile', function () {
    $user = User::factory()->create();

    $response = $this->getJson("/api/users/{$user->id}");

    $response->assertStatus(401);
});
```

### Testing API Endpoints

```php
<?php

use App\Models\User;

test('api returns paginated users', function () {
    User::factory()->count(25)->create();

    $response = $this->getJson('/api/users?page=1&per_page=10');

    $response->assertStatus(200)
        ->assertJsonStructure([
            'data' => [
                '*' => ['id', 'name', 'email'],
            ],
            'meta' => [
                'current_page',
                'total',
                'per_page',
            ],
        ])
        ->assertJsonCount(10, 'data');
});

test('api filters users by role', function () {
    User::factory()->count(5)->create(['role' => 'admin']);
    User::factory()->count(10)->create(['role' => 'editor']);

    $response = $this->getJson('/api/users?role=admin');

    $response->assertStatus(200)
        ->assertJsonCount(5, 'data');
});
```

### Testing Form Validation

```php
<?php

test('user creation requires name', function () {
    $response = $this->postJson('/api/users', [
        'email' => 'john@example.com',
        'password' => 'password',
    ]);

    $response->assertStatus(422)
        ->assertJsonValidationErrors(['name']);
});

test('user creation requires valid email', function ($email) {
    $response = $this->postJson('/api/users', [
        'name' => 'John Doe',
        'email' => $email,
        'password' => 'password',
    ]);

    $response->assertStatus(422)
        ->assertJsonValidationErrors(['email']);
})->with([
    'invalid-email',
    'missing@domain',
    '@example.com',
]);

test('password must be at least 8 characters', function () {
    $response = $this->postJson('/api/users', [
        'name' => 'John Doe',
        'email' => 'john@example.com',
        'password' => 'pass',
    ]);

    $response->assertStatus(422)
        ->assertJsonValidationErrors(['password']);
});
```

## Laravel Nova Testing

### Testing Nova Resources

```php
<?php

use App\Nova\User;
use Laravel\Nova\Http\Requests\NovaRequest;

test('nova user resource has correct fields', function () {
    $resource = new User(new \App\Models\User);
    $request = NovaRequest::create('/');

    $fields = $resource->fields($request);

    expect($fields)->toHaveCount(5);
});

test('nova user resource authorizes correctly', function () {
    $admin = \App\Models\User::factory()->admin()->create();
    $user = \App\Models\User::factory()->create();

    $request = NovaRequest::create('/', 'GET', [], [], [], [
        'HTTP_X_INERTIA' => 'true',
    ]);
    $request->setUserResolver(fn() => $admin);

    expect(User::authorizedToViewAny($request))->toBeTrue();

    $request->setUserResolver(fn() => $user);

    expect(User::authorizedToViewAny($request))->toBeFalse();
});
```

### Testing Nova Actions

```php
<?php

use App\Nova\Actions\ActivateUser;
use App\Models\User;
use Laravel\Nova\Fields\ActionFields;

test('nova action activates user', function () {
    $action = new ActivateUser();
    $users = User::factory()->count(3)->create(['status' => 'inactive']);

    $fields = new ActionFields(collect([]), collect([]));
    $result = $action->handle($fields, $users);

    expect($users->fresh()->every(fn($user) => $user->status === 'active'))
        ->toBeTrue();
});
```

### Testing Nova Filters

```php
<?php

use App\Nova\Filters\UserRole;
use Illuminate\Http\Request;

test('nova filter filters by role', function () {
    $filter = new UserRole();
    $request = Request::create('/');
    $query = \App\Models\User::query();

    $filtered = $filter->apply($request, $query, 'admin');

    expect($filtered->toSql())
        ->toContain("where `role` = ?");
});
```

## Database Testing

### Using Factories

```php
<?php

// database/factories/UserFactory.php
namespace Database\Factories;

use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Facades\Hash;

class UserFactory extends Factory
{
    public function definition(): array
    {
        return [
            'name' => fake()->name(),
            'email' => fake()->unique()->safeEmail(),
            'password' => Hash::make('password'),
            'status' => 'active',
        ];
    }

    public function admin(): static
    {
        return $this->state(fn (array $attributes) => [
            'role' => 'admin',
        ]);
    }

    public function inactive(): static
    {
        return $this->state(fn (array $attributes) => [
            'status' => 'inactive',
        ]);
    }
}

// Usage in tests
$user = User::factory()->create();
$admin = User::factory()->admin()->create();
$users = User::factory()->count(10)->create();
$inactive = User::factory()->inactive()->count(5)->create();
```

### Database Transactions

```php
<?php

use Illuminate\Foundation\Testing\RefreshDatabase;

// Option 1: Refresh database (slow, runs migrations)
uses(RefreshDatabase::class);

// Option 2: Database transactions (faster, recommended)
uses(Tests\TestCase::class)->in('Feature');

// In tests/TestCase.php
use Illuminate\Foundation\Testing\DatabaseTransactions;

abstract class TestCase extends BaseTestCase
{
    use CreatesApplication, DatabaseTransactions;
}
```

### Seeding Test Data

```php
<?php

test('products can be filtered', function () {
    $this->seed([
        CategorySeeder::class,
        ProductSeeder::class,
    ]);

    $response = $this->getJson('/api/products?category=electronics');

    $response->assertStatus(200);
});
```

## Mocking

### Mocking External APIs

```php
<?php

use Illuminate\Support\Facades\Http;

test('fetches data from external api', function () {
    Http::fake([
        'api.example.com/*' => Http::response([
            'data' => ['id' => 1, 'name' => 'Product'],
        ], 200),
    ]);

    $service = new ExternalApiService();
    $data = $service->fetchProduct(1);

    expect($data['name'])->toBe('Product');

    Http::assertSent(function ($request) {
        return $request->url() === 'https://api.example.com/products/1';
    });
});
```

### Mocking Jobs

```php
<?php

use Illuminate\Support\Facades\Queue;
use App\Jobs\ProcessUser;

test('user creation dispatches job', function () {
    Queue::fake();

    $response = $this->postJson('/api/users', [
        'name' => 'John Doe',
        'email' => 'john@example.com',
        'password' => 'password',
    ]);

    $response->assertStatus(201);

    Queue::assertPushed(ProcessUser::class, function ($job) {
        return $job->user->email === 'john@example.com';
    });
});
```

### Mocking Events

```php
<?php

use Illuminate\Support\Facades\Event;
use App\Events\UserCreated;

test('user creation fires event', function () {
    Event::fake([UserCreated::class]);

    User::factory()->create();

    Event::assertDispatched(UserCreated::class);
});
```

### Mocking Mail

```php
<?php

use Illuminate\Support\Facades\Mail;
use App\Mail\WelcomeEmail;

test('user creation sends welcome email', function () {
    Mail::fake();

    $user = User::factory()->create();

    Mail::assertSent(WelcomeEmail::class, function ($mail) use ($user) {
        return $mail->hasTo($user->email);
    });
});
```

## Frontend Testing (Vue)

### Component Testing with Vitest

```javascript
// tests/components/UserCard.test.js
import { describe, it, expect } from 'vitest'
import { mount } from '@vue/test-utils'
import UserCard from '@/components/UserCard.vue'

describe('UserCard', () => {
  it('renders user name', () => {
    const wrapper = mount(UserCard, {
      props: {
        user: {
          id: 1,
          name: 'John Doe',
          email: 'john@example.com'
        }
      }
    })

    expect(wrapper.text()).toContain('John Doe')
  })

  it('emits delete event when delete button clicked', async () => {
    const wrapper = mount(UserCard, {
      props: {
        user: { id: 1, name: 'John' }
      }
    })

    await wrapper.find('[data-test="delete-btn"]').trigger('click')

    expect(wrapper.emitted('delete')).toBeTruthy()
    expect(wrapper.emitted('delete')[0]).toEqual([1])
  })
})
```

### E2E Testing with Playwright

```javascript
// tests/e2e/users.spec.js
import { test, expect } from '@playwright/test'

test.describe('User Management', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/login')
    await page.fill('[name="email"]', 'admin@example.com')
    await page.fill('[name="password"]', 'password')
    await page.click('button[type="submit"]')
  })

  test('can create new user', async ({ page }) => {
    await page.goto('/users')
    await page.click('text=New User')

    await page.fill('[name="name"]', 'John Doe')
    await page.fill('[name="email"]', 'john@example.com')
    await page.selectOption('[name="role"]', 'editor')

    await page.click('text=Save')

    await expect(page.locator('text=User created successfully')).toBeVisible()
    await expect(page.locator('text=John Doe')).toBeVisible()
  })

  test('validates email format', async ({ page }) => {
    await page.goto('/users/create')

    await page.fill('[name="email"]', 'invalid-email')
    await page.click('text=Save')

    await expect(page.locator('text=Email is invalid')).toBeVisible()
  })
})
```

## Test Organization

### Directory Structure

```
tests/
├── Feature/           # HTTP tests, integration tests
│   ├── Api/
│   │   ├── UserControllerTest.php
│   │   └── PostControllerTest.php
│   └── Nova/
│       ├── UserResourceTest.php
│       └── UserActionTest.php
├── Unit/              # Unit tests for models, services
│   ├── Models/
│   │   ├── UserTest.php
│   │   └── PostTest.php
│   └── Services/
│       └── UserServiceTest.php
├── Browser/           # Laravel Dusk E2E tests
│   └── UserFlowTest.php
└── TestCase.php       # Base test case
```

### Naming Conventions

```php
// Test file: UserTest.php
// Test methods: test_user_can_be_created() or it('creates user')
// Factory: UserFactory.php
// Seeder: UserSeeder.php
```

## Coverage Reports

```bash
# Generate coverage report
php artisan test --coverage

# Generate HTML coverage report
php artisan test --coverage-html coverage

# Minimum coverage threshold
php artisan test --coverage --min=80
```

## CI/CD Integration

### GitHub Actions

```yaml
# .github/workflows/tests.yml
name: Tests

on: [push, pull_request]

jobs:
  tests:
    runs-on: ubuntu-latest

    services:
      mysql:
        image: mysql:8.0
        env:
          MYSQL_DATABASE: testing
          MYSQL_ROOT_PASSWORD: password
        ports:
          - 3306:3306

    steps:
      - uses: actions/checkout@v3

      - name: Setup PHP
        uses: shivammathur/setup-php@v2
        with:
          php-version: 8.3
          extensions: mbstring, pdo_mysql

      - name: Install dependencies
        run: composer install --prefer-dist --no-progress

      - name: Copy .env
        run: cp .env.example .env

      - name: Generate key
        run: php artisan key:generate

      - name: Run migrations
        run: php artisan migrate

      - name: Run tests
        run: php artisan test --coverage --min=70
```

## Best Practices

### 1. Test Naming
- Be descriptive: `test_user_can_create_post_with_valid_data()`
- Use natural language with Pest: `it('creates post with valid data')`

### 2. AAA Pattern
```php
test('user creation', function () {
    // Arrange
    $data = ['name' => 'John', 'email' => 'john@example.com'];

    // Act
    $user = User::create($data);

    // Assert
    expect($user->name)->toBe('John');
});
```

### 3. One Assertion Per Test (when possible)
```php
// Good
test('user has name', function () {
    $user = User::factory()->create(['name' => 'John']);
    expect($user->name)->toBe('John');
});

test('user has email', function () {
    $user = User::factory()->create(['email' => 'john@example.com']);
    expect($user->email)->toBe('john@example.com');
});

// Acceptable (related assertions)
test('user creation', function () {
    $user = User::factory()->create();
    expect($user)->toBeInstanceOf(User::class)
        ->and($user->id)->not->toBeNull();
});
```

### 4. Use Factories
- Always use factories instead of manual creation
- Keep test data generation in factories

### 5. Don't Test Framework
- Don't test Laravel's built-in functionality
- Focus on your application logic

### 6. Fast Tests
- Use in-memory SQLite for faster tests when possible
- Mock external services
- Use database transactions

### 7. Test Edge Cases
- Empty inputs
- Maximum values
- Invalid data
- Unauthorized access

## Common Testing Patterns

### Testing File Uploads

```php
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;

test('user can upload avatar', function () {
    Storage::fake('public');

    $file = UploadedFile::fake()->image('avatar.jpg');

    $response = $this->actingAs($user)
        ->post('/api/users/avatar', ['avatar' => $file]);

    $response->assertStatus(200);
    Storage::disk('public')->assertExists('avatars/' . $file->hashName());
});
```

### Testing Scheduled Tasks

```php
use Illuminate\Support\Facades\Artisan;

test('scheduled task runs successfully', function () {
    Artisan::call('users:cleanup');

    $this->assertDatabaseMissing('users', ['status' => 'deleted']);
});
```

### Testing Rate Limiting

```php
test('api rate limits requests', function () {
    for ($i = 0; $i < 60; $i++) {
        $this->getJson('/api/users');
    }

    $response = $this->getJson('/api/users');
    $response->assertStatus(429); // Too Many Requests
});
```
