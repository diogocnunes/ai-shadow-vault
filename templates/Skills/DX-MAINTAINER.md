---
name: dx-maintainer
description: Developer Experience and code quality maintenance for Laravel projects. Use when setting up code standards, configuring linters (PHPStan, Pint, ESLint, Prettier), implementing CI/CD pipelines, creating development workflows, establishing coding conventions, improving documentation, or reducing technical debt. Focuses on making codebases maintainable, consistent, and developer-friendly.
---

# DX Maintainer

Developer Experience and code quality guidance for maintainable Laravel projects.

## Philosophy

Good DX means:
- Code is easy to understand
- Consistent style across the project
- Fast feedback loops (tests, linting)
- Clear documentation
- Simple onboarding for new developers
- Automated quality checks

## Code Quality Tools

### Laravel Pint (Code Style)

Laravel Pint is an opinionated PHP code style fixer built on PHP-CS-Fixer.

```bash
# Installation
composer require laravel/pint --dev

# Run
./vendor/bin/pint

# Dry run (check without fixing)
./vendor/bin/pint --test

# Configuration (pint.json)
{
    "preset": "laravel",
    "rules": {
        "simplified_null_return": true,
        "braces": false,
        "new_with_braces": {
            "anonymous_class": false,
            "named_class": false
        }
    },
    "exclude": [
        "vendor",
        "node_modules"
    ]
}
```

**Available Presets:**
- `laravel` (recommended)
- `psr12`
- `symfony`
- `per` (PSR-12 Extended)

### PHPStan (Static Analysis)

Finds bugs without running code.

```bash
# Installation
composer require --dev phpstan/phpstan

# Run
./vendor/bin/phpstan analyse

# Configuration (phpstan.neon)
parameters:
    level: 8  # 0-9, higher is stricter
    paths:
        - app
        - config
        - database
        - routes
    excludePaths:
        - vendor
        - node_modules
    ignoreErrors:
        - '#Unsafe usage of new static#'  # Known Laravel pattern
```

**Levels:**
- 0-3: Basic checks
- 4-6: Recommended (catches most bugs)
- 7-8: Strict (requires more type hints)
- 9: Maximum strictness

**Laravel-specific package:**
```bash
composer require --dev larastan/larastan
```

### Psalm (Alternative to PHPStan)

```bash
composer require --dev vimeo/psalm
./vendor/bin/psalm --init
./vendor/bin/psalm
```

### PHP CS Fixer (Alternative to Pint)

```bash
composer require --dev friendsofphp/php-cs-fixer

# .php-cs-fixer.php
<?php

return (new PhpCsFixer\Config())
    ->setRules([
        '@PSR12' => true,
        'array_syntax' => ['syntax' => 'short'],
    ])
    ->setFinder(
        PhpCsFixer\Finder::create()
            ->in(__DIR__)
            ->exclude('vendor')
    );
```

## Frontend Code Quality

### ESLint (JavaScript/Vue)

```bash
# Installation
npm install --save-dev eslint @rushstack/eslint-patch
npm install --save-dev @vue/eslint-config-prettier
npm install --save-dev eslint-plugin-vue

# Configuration (.eslintrc.cjs)
module.exports = {
  root: true,
  extends: [
    'plugin:vue/vue3-essential',
    'eslint:recommended',
    '@vue/eslint-config-prettier'
  ],
  parserOptions: {
    ecmaVersion: 'latest'
  },
  rules: {
    'vue/multi-word-component-names': 'off',
    'no-console': process.env.NODE_ENV === 'production' ? 'warn' : 'off',
    'no-debugger': process.env.NODE_ENV === 'production' ? 'error' : 'off'
  }
}

# package.json
{
  "scripts": {
    "lint": "eslint . --ext .vue,.js,.jsx,.cjs,.mjs --fix --ignore-path .gitignore"
  }
}
```

### Prettier (Code Formatting)

```bash
npm install --save-dev prettier

# .prettierrc.json
{
  "semi": false,
  "singleQuote": true,
  "printWidth": 100,
  "trailingComma": "es5",
  "arrowParens": "always"
}

# .prettierignore
vendor
node_modules
public/build
storage

# package.json
{
  "scripts": {
    "format": "prettier --write 'resources/**/*.{js,vue,css}'"
  }
}
```

## Git Hooks (Husky + lint-staged)

Automatically run checks before commits.

```bash
npm install --save-dev husky lint-staged

# Initialize husky
npx husky install

# Add pre-commit hook
npx husky add .husky/pre-commit "npx lint-staged"

# package.json
{
  "lint-staged": {
    "*.php": [
      "./vendor/bin/pint"
    ],
    "*.{js,vue}": [
      "eslint --fix",
      "prettier --write"
    ]
  }
}
```

**Alternative: PHP Git Hooks**
```bash
composer require --dev brainmaestro/composer-git-hooks

# composer.json
{
    "extra": {
        "hooks": {
            "pre-commit": [
                "echo 'Running Pint...'",
                "./vendor/bin/pint --test"
            ],
            "pre-push": [
                "echo 'Running tests...'",
                "php artisan test"
            ]
        }
    }
}

php artisan hooks:install
```

## Code Quality Metrics

### Code Coverage

```bash
# Generate coverage report
php artisan test --coverage

# HTML report
php artisan test --coverage-html coverage

# Minimum threshold (fail if below)
php artisan test --coverage --min=80
```

### Cyclomatic Complexity

```bash
composer require --dev phpmetrics/phpmetrics

./vendor/bin/phpmetrics --report-html=metrics app/
```

**What to look for:**
- Complexity > 10: Consider refactoring
- Complexity > 20: Definitely refactor
- Aim for average complexity < 5

### Technical Debt

```bash
# PHP Insights
composer require nunomaduro/phpinsights --dev
php artisan insights

# Shows:
# - Code complexity
# - Architecture issues
# - Code style issues
# - Security vulnerabilities
```

## Documentation Standards

### PHPDoc Standards

```php
/**
 * Create a new user with the given data.
 *
 * @param array{name: string, email: string, password: string} $data
 * @return User
 * @throws \Illuminate\Validation\ValidationException
 */
public function createUser(array $data): User
{
    // Implementation
}

/**
 * Get active users with optional filtering.
 *
 * @param string|null $role Filter by role
 * @param int $limit Maximum number of users to return
 * @return \Illuminate\Database\Eloquent\Collection<int, User>
 */
public function getActiveUsers(?string $role = null, int $limit = 100): Collection
{
    // Implementation
}
```

### Project Documentation

Create these files in the root:

**README.md:**
```markdown
# Project Name

Brief description of what the project does.

## Requirements

- PHP 8.3+
- MySQL 8.0+
- Node.js 18+
- Redis (optional, for cache/queues)

## Installation

```bash
composer install
npm install
cp .env.example .env
php artisan key:generate
php artisan migrate --seed
npm run dev
```

## Development

```bash
# Run dev server
php artisan serve

# Run tests
php artisan test

# Run linter
./vendor/bin/pint

# Run static analysis
./vendor/bin/phpstan analyse
```

## Deployment

See [DEPLOYMENT.md](DEPLOYMENT.md) for production setup.
```

**CONTRIBUTING.md:**
```markdown
# Contributing

## Code Style

We use Laravel Pint for PHP code style:
```bash
./vendor/bin/pint
```

## Testing

All features must include tests:
```bash
php artisan test
```

## Pull Requests

1. Fork the repository
2. Create a feature branch
3. Write tests
4. Ensure all tests pass
5. Run Pint and PHPStan
6. Submit PR with clear description
```

**DEPLOYMENT.md:**
```markdown
# Deployment

## Production Checklist

- [ ] Run tests: `php artisan test`
- [ ] Check code style: `./vendor/bin/pint --test`
- [ ] Static analysis: `./vendor/bin/phpstan analyse`
- [ ] Update .env with production values
- [ ] Set APP_DEBUG=false
- [ ] Generate app key: `php artisan key:generate`
- [ ] Run migrations: `php artisan migrate --force`
- [ ] Optimize: `php artisan optimize`
- [ ] Cache config: `php artisan config:cache`
- [ ] Cache routes: `php artisan route:cache`
- [ ] Compile assets: `npm run build`

## Environment Variables

Document all required .env variables here.
```

## CI/CD Setup

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
        options: --health-cmd="mysqladmin ping" --health-interval=10s --health-timeout=5s --health-retries=3

    steps:
      - uses: actions/checkout@v4

      - name: Setup PHP
        uses: shivammathur/setup-php@v2
        with:
          php-version: 8.3
          extensions: mbstring, pdo_mysql, redis
          coverage: xdebug

      - name: Install Composer dependencies
        run: composer install --prefer-dist --no-progress

      - name: Copy .env
        run: cp .env.example .env

      - name: Generate key
        run: php artisan key:generate

      - name: Run migrations
        run: php artisan migrate --force

      - name: Run Pint
        run: ./vendor/bin/pint --test

      - name: Run PHPStan
        run: ./vendor/bin/phpstan analyse

      - name: Run tests
        run: php artisan test --coverage --min=70

  frontend:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Setup Node
        uses: actions/setup-node@v4
        with:
          node-version: 18

      - name: Install dependencies
        run: npm ci

      - name: Run ESLint
        run: npm run lint

      - name: Build assets
        run: npm run build
```

### GitLab CI

```yaml
# .gitlab-ci.yml
stages:
  - test
  - deploy

variables:
  MYSQL_DATABASE: testing
  MYSQL_ROOT_PASSWORD: password

cache:
  paths:
    - vendor/
    - node_modules/

test:php:
  stage: test
  image: php:8.3
  services:
    - mysql:8.0
  before_script:
    - apt-get update -qq && apt-get install -y -qq git unzip
    - curl -sS https://getcomposer.org/installer | php
    - php composer.phar install
  script:
    - cp .env.example .env
    - php artisan key:generate
    - php artisan migrate
    - ./vendor/bin/pint --test
    - ./vendor/bin/phpstan analyse
    - php artisan test --coverage --min=70

test:frontend:
  stage: test
  image: node:18
  script:
    - npm ci
    - npm run lint
    - npm run build

deploy:production:
  stage: deploy
  only:
    - main
  script:
    - echo "Deploy to production"
```

## IDE Configuration

### VS Code

```json
// .vscode/settings.json
{
  "editor.formatOnSave": true,
  "editor.codeActionsOnSave": {
    "source.fixAll.eslint": true
  },
  "[php]": {
    "editor.defaultFormatter": "open-southeners.laravel-pint"
  },
  "[vue]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode"
  },
  "php.validate.executablePath": "/usr/bin/php",
  "phpstan.enabled": true,
  "phpstan.path": "vendor/bin/phpstan"
}

// .vscode/extensions.json (recommended extensions)
{
  "recommendations": [
    "open-southeners.laravel-pint",
    "bmewburn.vscode-intelephense-client",
    "vue.volar",
    "dbaeumer.vscode-eslint",
    "esbenp.prettier-vscode"
  ]
}
```

### PHPStorm

```xml
<!-- .idea/php.xml -->
<project version="4">
  <component name="PhpProjectSharedConfiguration" php_language_level="8.3" />
  <component name="PhpUnit">
    <option name="directories">
      <list>
        <option value="$PROJECT_DIR$/tests" />
      </list>
    </option>
  </component>
</project>
```

## Code Review Checklist

### General
- [ ] Code follows project style guide
- [ ] No commented-out code (use version control)
- [ ] No TODO comments without tickets
- [ ] Variable names are descriptive
- [ ] Functions are small (< 50 lines)
- [ ] No duplicate code
- [ ] Error handling is present

### Laravel Specific
- [ ] Uses Eloquent over raw queries
- [ ] Proper use of mass assignment protection
- [ ] Authorization checks present
- [ ] Input validation in place
- [ ] N+1 queries prevented
- [ ] Proper use of transactions
- [ ] Queue used for long-running tasks

### Testing
- [ ] Tests exist for new features
- [ ] Tests pass locally
- [ ] Coverage doesn't decrease
- [ ] Edge cases covered
- [ ] Mocking used appropriately

### Documentation
- [ ] PHPDoc comments for complex functions
- [ ] README updated if needed
- [ ] CHANGELOG updated
- [ ] API documentation updated

## Coding Standards

### Naming Conventions

```php
// Classes: PascalCase
class UserController {}

// Methods: camelCase
public function getUserById() {}

// Variables: camelCase
$userId = 1;

// Constants: SCREAMING_SNAKE_CASE
const MAX_LOGIN_ATTEMPTS = 5;

// Database tables: snake_case plural
users, blog_posts, user_roles

// Database columns: snake_case
user_id, created_at, first_name

// Routes: kebab-case
/users/create-account
/blog-posts/edit

// Views: kebab-case
resources/views/users/create-account.blade.php
```

### File Organization

```
app/
├── Actions/           # Single-purpose actions
├── Console/          # Artisan commands
├── DTOs/             # Data Transfer Objects
├── Events/           # Event classes
├── Exceptions/       # Custom exceptions
├── Http/
│   ├── Controllers/  # Keep thin
│   ├── Middleware/
│   └── Requests/     # Form requests
├── Jobs/             # Queue jobs
├── Listeners/        # Event listeners
├── Mail/             # Mailable classes
├── Models/           # Eloquent models
├── Nova/             # Nova resources
├── Observers/        # Model observers
├── Policies/         # Authorization
├── Providers/        # Service providers
├── Rules/            # Custom validation rules
├── Services/         # Business logic
└── Support/          # Helpers, utilities
```

### Laravel Best Practices

```php
// ✅ GOOD: Thin controllers
public function store(StoreUserRequest $request, UserService $service)
{
    $user = $service->create($request->validated());
    return new UserResource($user);
}

// ❌ BAD: Fat controllers
public function store(Request $request)
{
    $validated = $request->validate([...]);
    $user = User::create($validated);
    $user->assignRole('editor');
    Mail::to($user->email)->send(new WelcomeEmail($user));
    event(new UserCreated($user));
    return new UserResource($user);
}

// ✅ GOOD: Named routes
return redirect()->route('users.show', $user);

// ❌ BAD: Hard-coded URLs
return redirect('/users/' . $user->id);

// ✅ GOOD: Use config values
$maxAttempts = config('auth.max_login_attempts');

// ❌ BAD: Magic numbers
$maxAttempts = 5;
```

## Dependency Management

### Keep Dependencies Updated

```bash
# Check for outdated packages
composer outdated

# Update dependencies
composer update

# Update specific package
composer update laravel/framework

# Check for security vulnerabilities
composer audit
```

### Lock File Management

- Always commit `composer.lock` and `package-lock.json`
- Update dependencies regularly (weekly or monthly)
- Test thoroughly after updates
- Document breaking changes

## Performance Monitoring

### New Relic Setup

```php
// config/newrelic.php
return [
    'enabled' => env('NEW_RELIC_ENABLED', false),
    'app_name' => env('NEW_RELIC_APP_NAME', 'Laravel App'),
    'license_key' => env('NEW_RELIC_LICENSE_KEY'),
];
```

### Error Tracking (Sentry)

```bash
composer require sentry/sentry-laravel

# .env
SENTRY_LARAVEL_DSN=your-dsn-here

# Usage
try {
    // Code
} catch (\Exception $e) {
    report($e); // Automatically sent to Sentry
    throw $e;
}
```

## Developer Onboarding

### Onboarding Checklist

Create `ONBOARDING.md`:

```markdown
# Developer Onboarding

## Day 1

- [ ] Clone repository
- [ ] Install PHP 8.3, Composer, Node.js
- [ ] Run `composer install && npm install`
- [ ] Set up .env file
- [ ] Run migrations: `php artisan migrate --seed`
- [ ] Run tests: `php artisan test`
- [ ] Set up IDE (VS Code/PHPStorm)
- [ ] Install browser extension (Vue DevTools)
- [ ] Read README.md and CONTRIBUTING.md

## Day 2-3

- [ ] Understand project structure
- [ ] Review coding standards
- [ ] Review existing PRs
- [ ] Set up development workflow
- [ ] Make first small contribution

## Resources

- [Laravel Docs](https://laravel.com/docs)
- [Vue 3 Docs](https://vuejs.org)
- [PrimeVue Docs](https://primevue.org)
- [Internal Wiki](link)
```

## Maintenance Tasks

### Regular Tasks

**Weekly:**
- [ ] Update dependencies
- [ ] Review open issues
- [ ] Check for failing tests
- [ ] Review code coverage

**Monthly:**
- [ ] Run security audit
- [ ] Review and update documentation
- [ ] Clean up unused code
- [ ] Optimize database (analyze, vacuum)
- [ ] Review and archive old branches

**Quarterly:**
- [ ] Review and update tech stack
- [ ] Plan refactoring of technical debt
- [ ] Update CI/CD pipeline
- [ ] Team retrospective on DX

## Best Practices Summary

### Code Quality
✅ Use static analysis (PHPStan)
✅ Enforce code style (Pint)
✅ Write comprehensive tests
✅ Review code before merging
✅ Keep dependencies updated

### Documentation
✅ Document complex logic
✅ Keep README up-to-date
✅ Write clear commit messages
✅ Create ADRs for big decisions

### Developer Experience
✅ Fast test suite (< 1 minute)
✅ Simple setup process
✅ Clear error messages
✅ Helpful IDE support
✅ Automated quality checks

### Maintenance
✅ Regular dependency updates
✅ Monitor for issues
✅ Reduce technical debt
✅ Keep documentation current
