---
name: filament-expert
description: Expert guidance for building admin panels with Filament PHP (v3.x). Use when creating or modifying Filament resources, forms, tables, actions, widgets, custom pages, relation managers, or troubleshooting Filament-specific issues. Covers form builders, table builders, notifications, actions, authorization, theming, and best practices for Laravel admin panels.
---

# Filament Expert

Expert guidance for building professional admin panels with Filament PHP v3.x.

## Core Principles

**Resource-First Approach**: Start with Resources for CRUD operations. Resources automatically generate list, create, edit, and view pages.

**Component Composition**: Build complex interfaces by composing simple components (Fields, Columns, Actions, Filters).

**Convention Over Configuration**: Follow Filament conventions for automatic behavior (relationship inference, model binding, authorization).

## Resource Structure

### Basic Resource

```php
class PostResource extends Resource
{
    protected static ?string $model = Post::class;
    protected static ?string $navigationIcon = 'heroicon-o-document-text';
    protected static ?string $navigationGroup = 'Content';
    protected static ?string $navigationLabel = 'Posts';
    protected static ?int $navigationSort = 1;
    
    public static function form(Form $form): Form
    {
        return $form->schema([
            TextInput::make('title')->required(),
            RichEditor::make('content')->required(),
            Select::make('status')
                ->options([
                    'draft' => 'Draft',
                    'published' => 'Published',
                ])
                ->default('draft'),
        ]);
    }
    
    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                TextColumn::make('title')->searchable()->sortable(),
                TextColumn::make('status')->badge(),
                TextColumn::make('created_at')->dateTime(),
            ])
            ->filters([
                SelectFilter::make('status')
                    ->options([
                        'draft' => 'Draft',
                        'published' => 'Published',
                    ]),
            ])
            ->actions([
                Tables\Actions\EditAction::make(),
                Tables\Actions\DeleteAction::make(),
            ])
            ->bulkActions([
                Tables\Actions\BulkActions\DeleteBulkAction::make(),
            ]);
    }
    
    public static function getPages(): array
    {
        return [
            'index' => Pages\ListPosts::route('/'),
            'create' => Pages\CreatePost::route('/create'),
            'edit' => Pages\EditPost::route('/{record}/edit'),
        ];
    }
}
```

## Form Components

**Layout Components**: Use `Grid`, `Section`, `Tabs`, `Fieldset`, `Group` to organize forms.

```php
Section::make('Post Details')
    ->description('Basic information about the post')
    ->schema([
        TextInput::make('title')->required(),
        Textarea::make('excerpt'),
    ])
    ->columns(2),

Tabs::make('Content')
    ->tabs([
        Tab::make('Content')->schema([
            RichEditor::make('content'),
        ]),
        Tab::make('SEO')->schema([
            TextInput::make('meta_title'),
            Textarea::make('meta_description'),
        ]),
    ]),
```

**Common Fields**:
- `TextInput` - Single-line text with masks, validation, prefixes/suffixes
- `Textarea` - Multi-line text with row control
- `RichEditor` - WYSIWYG editor with toolbar customization
- `MarkdownEditor` - Markdown with preview
- `Select` - Dropdown with search, multiple selection
- `CheckboxList` - Multiple checkboxes in grid/list
- `Radio` - Radio buttons
- `Toggle` - Boolean switch
- `FileUpload` - Image/file uploads with preview, validation, multiple files
- `DatePicker` / `DateTimePicker` - Date/time selection
- `Repeater` - Dynamic field groups with min/max items
- `Builder` - Block-based content builder
- `KeyValue` - Key-value pair editor

**Relationship Fields**:
```php
Select::make('author_id')
    ->relationship('author', 'name')
    ->searchable()
    ->preload()
    ->createOptionForm([
        TextInput::make('name')->required(),
        TextInput::make('email')->email()->required(),
    ])
    ->editOptionForm([
        TextInput::make('name')->required(),
        TextInput::make('email')->email()->required(),
    ]),

// BelongsToMany with pivot data
Select::make('categories')
    ->relationship('categories', 'name')
    ->multiple()
    ->preload(),
```

**Reactive Forms**:
```php
Select::make('type')
    ->options([
        'article' => 'Article',
        'video' => 'Video',
    ])
    ->live(),

TextInput::make('video_url')
    ->visible(fn (Get $get) => $get('type') === 'video')
    ->required(fn (Get $get) => $get('type') === 'video'),
```

## Table Components

**Columns**:
```php
TextColumn::make('title')
    ->searchable()
    ->sortable()
    ->toggleable()
    ->limit(50)
    ->tooltip(fn ($record) => $record->title)
    ->description(fn ($record) => $record->excerpt),
    
ImageColumn::make('featured_image')
    ->circular()
    ->size(40),
    
TextColumn::make('price')
    ->money('eur')
    ->sortable()
    ->summarize([
        Tables\Columns\Summarizers\Sum::make(),
        Tables\Columns\Summarizers\Average::make(),
    ]),

BadgeColumn::make('status')
    ->colors([
        'danger' => 'draft',
        'success' => 'published',
        'warning' => 'scheduled',
    ]),

IconColumn::make('is_featured')
    ->boolean(),

SelectColumn::make('status')
    ->options([
        'draft' => 'Draft',
        'published' => 'Published',
    ]),
```

**Advanced Table Features**:
```php
->modifyQueryUsing(fn (Builder $query) => $query->with('author'))
->defaultSort('created_at', 'desc')
->persistSearchInSession()
->persistFiltersInSession()
->striped()
->poll('30s')
->deferLoading()
->groups([
    Group::make('status')
        ->titlePrefixedWithLabel(false),
])
```

**Filters**:
```php
SelectFilter::make('status')
    ->options([
        'draft' => 'Draft',
        'published' => 'Published',
    ])
    ->multiple(),

TernaryFilter::make('is_featured')
    ->label('Featured')
    ->placeholder('All posts')
    ->trueLabel('Featured posts')
    ->falseLabel('Not featured'),

Filter::make('created_at')
    ->form([
        DatePicker::make('created_from'),
        DatePicker::make('created_until'),
    ])
    ->query(function (Builder $query, array $data): Builder {
        return $query
            ->when(
                $data['created_from'],
                fn (Builder $query, $date): Builder => $query->whereDate('created_at', '>=', $date),
            )
            ->when(
                $data['created_until'],
                fn (Builder $query, $date): Builder => $query->whereDate('created_at', '<=', $date),
            );
    }),
```

## Actions & Notifications

**Table Actions**:
```php
Tables\Actions\Action::make('publish')
    ->icon('heroicon-o-check')
    ->color('success')
    ->requiresConfirmation()
    ->modalHeading('Publish post?')
    ->modalSubheading('The post will be visible to all users.')
    ->action(function (Post $record) {
        $record->update(['status' => 'published', 'published_at' => now()]);
        
        Notification::make()
            ->title('Post published successfully')
            ->success()
            ->send();
    })
    ->visible(fn (Post $record) => $record->status === 'draft'),

// Action with form
Tables\Actions\Action::make('schedule')
    ->form([
        DateTimePicker::make('published_at')
            ->required()
            ->minDate(now()),
    ])
    ->action(function (Post $record, array $data) {
        $record->update([
            'status' => 'scheduled',
            'published_at' => $data['published_at'],
        ]);
    }),
```

**Bulk Actions**:
```php
Tables\Actions\BulkAction::make('publish')
    ->icon('heroicon-o-check')
    ->requiresConfirmation()
    ->action(fn (Collection $records) => 
        $records->each->update(['status' => 'published'])
    )
    ->deselectRecordsAfterCompletion(),

Tables\Actions\BulkAction::make('updateAuthor')
    ->form([
        Select::make('author_id')
            ->relationship('author', 'name')
            ->required(),
    ])
    ->action(function (Collection $records, array $data) {
        $records->each->update(['author_id' => $data['author_id']]);
    }),
```

**Header Actions**:
```php
Tables\Actions\CreateAction::make()
    ->mutateFormDataUsing(function (array $data) {
        $data['user_id'] = auth()->id();
        return $data;
    }),

Tables\Actions\Action::make('import')
    ->form([
        FileUpload::make('file')
            ->acceptedFileTypes(['text/csv'])
            ->required(),
    ])
    ->action(function (array $data) {
        // Import logic
    }),
```

## Relation Managers

```php
// In Resource
public static function getRelations(): array
{
    return [
        RelationManagers\CommentsRelationManager::class,
        RelationManagers\TagsRelationManager::class,
    ];
}

// CommentsRelationManager.php
class CommentsRelationManager extends RelationManager
{
    protected static string $relationship = 'comments';
    protected static ?string $recordTitleAttribute = 'content';
    
    public function form(Form $form): Form
    {
        return $form->schema([
            Textarea::make('content')->required()->rows(3),
            Select::make('status')
                ->options([
                    'approved' => 'Approved',
                    'pending' => 'Pending',
                    'spam' => 'Spam',
                ])
                ->default('pending'),
        ]);
    }
    
    public function table(Table $table): Table
    {
        return $table
            ->recordTitleAttribute('content')
            ->columns([
                TextColumn::make('author.name')->label('Author'),
                TextColumn::make('content')->limit(50),
                BadgeColumn::make('status'),
                TextColumn::make('created_at')->dateTime(),
            ])
            ->filters([
                SelectFilter::make('status')
                    ->options([
                        'approved' => 'Approved',
                        'pending' => 'Pending',
                        'spam' => 'Spam',
                    ]),
            ])
            ->headerActions([
                Tables\Actions\CreateAction::make(),
                Tables\Actions\AttachAction::make(), // For BelongsToMany
            ])
            ->actions([
                Tables\Actions\EditAction::make(),
                Tables\Actions\DeleteAction::make(),
                Tables\Actions\DetachAction::make(), // For BelongsToMany
            ])
            ->bulkActions([
                Tables\Actions\BulkActionGroup::make([
                    Tables\Actions\DeleteBulkAction::make(),
                ]),
            ]);
    }
}
```

## Authorization

Filament automatically checks Laravel Policies:
- `viewAny()` - Can view resource list page
- `view()` - Can view single record
- `create()` - Can create new records
- `update()` - Can edit records
- `delete()` - Can delete records
- `deleteAny()` - Can bulk delete
- `forceDelete()` - Can force delete soft-deleted
- `restore()` - Can restore soft-deleted

```php
// PostPolicy.php
class PostPolicy
{
    public function viewAny(User $user): bool
    {
        return $user->can('view_posts');
    }

    public function create(User $user): bool
    {
        return $user->can('create_posts');
    }

    public function update(User $user, Post $post): bool
    {
        return $user->can('edit_posts') || $post->author_id === $user->id;
    }
}

// Register in AuthServiceProvider
protected $policies = [
    Post::class => PostPolicy::class,
];
```

## Custom Pages

```php
// In Resource
public static function getPages(): array
{
    return [
        'index' => Pages\ListPosts::route('/'),
        'create' => Pages\CreatePost::route('/create'),
        'edit' => Pages\EditPost::route('/{record}/edit'),
        'analytics' => Pages\PostAnalytics::route('/{record}/analytics'),
    ];
}

// PostAnalytics.php
use Filament\Resources\Pages\Page;

class PostAnalytics extends Page
{
    protected static string $resource = PostResource::class;
    protected static string $view = 'filament.resources.posts.pages.analytics';
    protected static ?string $title = 'Analytics';
    protected static ?string $navigationIcon = 'heroicon-o-chart-bar';
    
    public function mount(int | string $record): void
    {
        $this->record = $this->resolveRecord($record);
    }
}
```

**Standalone Custom Pages** (not tied to a Resource):
```php
// app/Filament/Pages/Settings.php
use Filament\Pages\Page;
use Filament\Forms;

class Settings extends Page implements Forms\Contracts\HasForms
{
    use Forms\Concerns\InteractsWithForms;
    
    protected static ?string $navigationIcon = 'heroicon-o-cog';
    protected static string $view = 'filament.pages.settings';
    
    public ?array $data = [];
    
    public function mount(): void
    {
        $this->form->fill([
            'site_name' => setting('site_name'),
            'admin_email' => setting('admin_email'),
        ]);
    }
    
    protected function getFormSchema(): array
    {
        return [
            Forms\Components\TextInput::make('site_name')->required(),
            Forms\Components\TextInput::make('admin_email')->email()->required(),
        ];
    }
    
    public function submit(): void
    {
        $data = $this->form->getState();
        
        setting(['site_name' => $data['site_name']]);
        setting(['admin_email' => $data['admin_email']]);
        
        Notification::make()
            ->title('Settings saved')
            ->success()
            ->send();
    }
}
```

## Widgets

```php
// StatsOverview.php
use Filament\Widgets\StatsOverviewWidget as BaseWidget;
use Filament\Widgets\StatsOverviewWidget\Stat;

class StatsOverview extends BaseWidget
{
    protected static ?int $sort = 1;
    protected static ?string $pollingInterval = '30s';
    
    protected function getStats(): array
    {
        return [
            Stat::make('Total Posts', Post::count())
                ->description('All time posts')
                ->descriptionIcon('heroicon-m-document-text')
                ->chart([7, 2, 10, 3, 15, 4, 17])
                ->color('success'),
                
            Stat::make('Published', Post::where('status', 'published')->count())
                ->description('7% increase')
                ->descriptionIcon('heroicon-m-arrow-trending-up')
                ->color('success'),
                
            Stat::make('Draft', Post::where('status', 'draft')->count())
                ->color('gray'),
        ];
    }
}

// ChartWidget.php
use Filament\Widgets\ChartWidget;

class PostsChart extends ChartWidget
{
    protected static ?string $heading = 'Posts Per Month';
    protected static ?int $sort = 2;
    
    protected function getData(): array
    {
        return [
            'datasets' => [
                [
                    'label' => 'Posts created',
                    'data' => [0, 10, 5, 2, 21, 32, 45],
                ],
            ],
            'labels' => ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul'],
        ];
    }

    protected function getType(): string
    {
        return 'line';
    }
}

// Register in PanelProvider or Dashboard
public function panel(Panel $panel): Panel
{
    return $panel
        ->widgets([
            StatsOverview::class,
            PostsChart::class,
        ]);
}
```

## Global Search

```php
// In Resource
protected static ?string $recordTitleAttribute = 'title';

public static function getGlobalSearchResultTitle(Model $record): string
{
    return $record->title;
}

public static function getGloballySearchableAttributes(): array
{
    return ['title', 'content', 'author.name'];
}

public static function getGlobalSearchResultDetails(Model $record): array
{
    return [
        'Author' => $record->author->name,
        'Status' => $record->status,
        'Date' => $record->created_at->format('M d, Y'),
    ];
}

public static function getGlobalSearchResultUrl(Model $record): string
{
    return PostResource::getUrl('edit', ['record' => $record]);
}
```

## Common Patterns

**Computed/Derived State**:
```php
TextInput::make('slug')
    ->required()
    ->unique(ignoreRecord: true)
    ->afterStateHydrated(function (TextInput $component, ?string $state, $record) {
        if (! $state && $record?->title) {
            $component->state(Str::slug($record->title));
        }
    }),
```

**Dependent Selects**:
```php
Select::make('country_id')
    ->relationship('country', 'name')
    ->searchable()
    ->live()
    ->afterStateUpdated(fn (callable $set) => $set('state_id', null)),

Select::make('state_id')
    ->relationship(
        name: 'state',
        titleAttribute: 'name',
        modifyQueryUsing: fn (Builder $query, Get $get) => 
            $query->where('country_id', $get('country_id'))
    )
    ->searchable()
    ->preload(),
```

**File Upload with Preview**:
```php
FileUpload::make('images')
    ->image()
    ->multiple()
    ->maxFiles(5)
    ->maxSize(2048)
    ->imageEditor()
    ->imageEditorAspectRatios([
        '16:9',
        '4:3',
        '1:1',
    ])
    ->disk('public')
    ->directory('posts')
    ->visibility('public')
    ->downloadable()
    ->openable(),
```

**Complex Repeater**:
```php
Repeater::make('features')
    ->schema([
        TextInput::make('title')->required(),
        Textarea::make('description')->rows(2),
        FileUpload::make('icon')->image(),
        Toggle::make('is_highlighted')->default(false),
    ])
    ->columns(2)
    ->collapsed()
    ->itemLabel(fn (array $state): ?string => $state['title'] ?? null)
    ->addActionLabel('Add feature')
    ->defaultItems(0)
    ->reorderable()
    ->collapsible(),
```

**Custom Form Actions**:
```php
// In CreatePost or EditPost page
protected function getFormActions(): array
{
    return [
        Action::make('save')
            ->label('Save')
            ->action('save'),
            
        Action::make('saveAndPublish')
            ->label('Save & Publish')
            ->action('saveAndPublish'),
            
        Action::make('cancel')
            ->label('Cancel')
            ->url($this->getResource()::getUrl('index'))
            ->color('gray'),
    ];
}

public function saveAndPublish(): void
{
    $this->form->getState();
    
    $this->record->update([
        'status' => 'published',
        'published_at' => now(),
    ]);
    
    $this->redirect($this->getResource()::getUrl('index'));
}
```

## Theming

**Color Customization** in PanelProvider:
```php
use Filament\Support\Colors\Color;

public function panel(Panel $panel): Panel
{
    return $panel
        ->colors([
            'primary' => Color::Amber,
            'danger' => Color::Rose,
            'gray' => Color::Gray,
            'info' => Color::Blue,
            'success' => Color::Emerald,
            'warning' => Color::Orange,
        ]);
}
```

**Custom Theme**:
```bash
php artisan make:filament-theme
```

## Troubleshooting

**Common Issues**:

1. **Navigation not appearing**
   - Check `$model` is set
   - Verify `$navigationIcon` exists
   - Check authorization (`viewAny` policy)

2. **Form not saving**
   - Verify fields are in model's `$fillable`
   - Check validation rules
   - Inspect `mutateFormDataBeforeCreate/Save`

3. **Relationships not loading**
   - Verify relationship method exists in model
   - Check `relationship()` field name matches
   - Use `->preload()` for better UX

4. **Authorization errors**
   - Register policy in `AuthServiceProvider`
   - Check all required policy methods
   - Verify user has permissions

5. **Search not working**
   - Add `->searchable()` to columns
   - Check database indexes
   - Verify model attributes are accessible

**Performance Optimization**:
- Use `->deferLoading()` for heavy tables
- Add database indexes to searchable/sortable columns
- Use `->preload()` carefully (only for small datasets)
- Implement eager loading with `modifyQueryUsing()`
- Enable query caching where appropriate

## Best Practices

1. **Resource Organization**: Group related resources with `$navigationGroup`
2. **Validation**: Use Laravel validation rules in form fields
3. **Authorization**: Always implement policies for resources
4. **Relationships**: Use `->relationship()` for better UX
5. **Actions**: Provide clear confirmation messages
6. **Performance**: Eager load relationships in table queries
7. **User Feedback**: Use notifications for important actions
8. **Code Reusability**: Extract common form schemas to traits
9. **Testing**: Write tests for custom actions and logic
10. **Documentation**: Comment complex logic in custom pages

## Quick Reference Commands

```bash
# Create Resource
php artisan make:filament-resource Post --generate

# Create Custom Page
php artisan make:filament-page Settings

# Create Widget
php artisan make:filament-widget StatsOverview

# Create Relation Manager
php artisan make:filament-relation-manager PostResource comments content

# Clear Cache
php artisan filament:clear-cached-components
```
