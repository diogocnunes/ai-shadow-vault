---
name: filament-v5
description: Expert guidance for building admin panels with Filament PHP v5+. Use when creating or modifying Filament resources, forms, tables, actions, widgets, custom pages, relation managers, or troubleshooting Filament-specific issues. Covers Livewire 3, improved performance, new component APIs, enhanced table builder, form improvements, and modern Laravel integration patterns.
---

# Filament v5 Expert

Expert guidance for building professional admin panels with Filament PHP v5+ (Livewire 3 based).

## What's New in Filament v5

**Livewire 3 Foundation**: Built on Livewire 3 for better performance and modern patterns
**Improved Performance**: Lazy loading, deferred rendering, optimized queries
**Enhanced Components**: New component APIs with better type hints and IDE support
**Better Form Builder**: Improved field composition and conditional logic
**Advanced Tables**: Enhanced filtering, sorting, and grouping capabilities
**Modern PHP**: Requires PHP 8.1+ with full attribute support

## Core Principles

**Component Composition**: Build complex UIs by composing simple, reusable components
**Type Safety**: Leverage PHP 8.1+ features (enums, attributes, typed properties)
**Performance First**: Use lazy loading, query optimization, and caching strategically
**Convention Over Configuration**: Follow Filament conventions for automatic behavior

## Resource Structure

### Modern Resource (v5)

```php
<?php

namespace App\Filament\Resources;

use Filament\Forms;
use Filament\Forms\Form;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Table;
use App\Models\Post;
use App\Filament\Resources\PostResource\Pages;

class PostResource extends Resource
{
    protected static ?string $model = Post::class;
    
    protected static ?string $navigationIcon = 'heroicon-o-document-text';
    
    protected static ?string $navigationGroup = 'Content';
    
    protected static ?int $navigationSort = 1;
    
    // v5: Record title for breadcrumbs and titles
    public static function getRecordTitle(Model $record): string
    {
        return $record->title;
    }
    
    public static function form(Form $form): Form
    {
        return $form
            ->schema([
                Forms\Components\Section::make('Post Content')
                    ->schema([
                        Forms\Components\TextInput::make('title')
                            ->required()
                            ->maxLength(255)
                            ->live(onBlur: true)
                            ->afterStateUpdated(fn (Set $set, ?string $state) => 
                                $set('slug', Str::slug($state))
                            ),
                        
                        Forms\Components\TextInput::make('slug')
                            ->required()
                            ->unique(ignoreRecord: true)
                            ->maxLength(255),
                        
                        Forms\Components\RichEditor::make('content')
                            ->required()
                            ->columnSpanFull()
                            ->fileAttachmentsDisk('public')
                            ->fileAttachmentsDirectory('attachments'),
                        
                        Forms\Components\Select::make('status')
                            ->options([
                                'draft' => 'Draft',
                                'reviewing' => 'Reviewing',
                                'published' => 'Published',
                            ])
                            ->default('draft')
                            ->required()
                            ->native(false), // v5: Better styling
                    ])
                    ->columns(2),
                
                Forms\Components\Section::make('Metadata')
                    ->schema([
                        Forms\Components\Select::make('author_id')
                            ->relationship('author', 'name')
                            ->searchable()
                            ->preload()
                            ->required(),
                        
                        Forms\Components\DateTimePicker::make('published_at')
                            ->native(false),
                        
                        Forms\Components\TagsInput::make('tags')
                            ->separator(','),
                    ])
                    ->columns(2),
            ]);
    }
    
    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                Tables\Columns\TextColumn::make('title')
                    ->searchable()
                    ->sortable()
                    ->description(fn (Post $record): string => 
                        Str::limit($record->excerpt, 50)
                    ),
                
                Tables\Columns\TextColumn::make('author.name')
                    ->sortable()
                    ->searchable(),
                
                Tables\Columns\SelectColumn::make('status')
                    ->options([
                        'draft' => 'Draft',
                        'reviewing' => 'Reviewing',
                        'published' => 'Published',
                    ]),
                
                Tables\Columns\TextColumn::make('published_at')
                    ->dateTime()
                    ->sortable()
                    ->toggleable(),
                
                Tables\Columns\TextColumn::make('created_at')
                    ->dateTime()
                    ->sortable()
                    ->toggleable(isToggledHiddenByDefault: true),
            ])
            ->filters([
                Tables\Filters\SelectFilter::make('author')
                    ->relationship('author', 'name')
                    ->searchable()
                    ->preload(),
                
                Tables\Filters\SelectFilter::make('status')
                    ->options([
                        'draft' => 'Draft',
                        'reviewing' => 'Reviewing',
                        'published' => 'Published',
                    ])
                    ->multiple(),
                
                Tables\Filters\TrashedFilter::make(),
            ])
            ->actions([
                Tables\Actions\ViewAction::make(),
                Tables\Actions\EditAction::make(),
                Tables\Actions\DeleteAction::make(),
            ])
            ->bulkActions([
                Tables\Actions\BulkActionGroup::make([
                    Tables\Actions\DeleteBulkAction::make(),
                    Tables\Actions\RestoreBulkAction::make(),
                    Tables\Actions\ForceDeleteBulkAction::make(),
                ]),
            ])
            ->defaultSort('created_at', 'desc')
            ->persistSearchInSession()
            ->persistFiltersInSession()
            ->deferLoading()
            ->striped();
    }
    
    public static function getRelations(): array
    {
        return [
            //
        ];
    }
    
    public static function getPages(): array
    {
        return [
            'index' => Pages\ListPosts::route('/'),
            'create' => Pages\CreatePost::route('/create'),
            'view' => Pages\ViewPost::route('/{record}'),
            'edit' => Pages\EditPost::route('/{record}/edit'),
        ];
    }
}
```

## Form Components v5

### Enhanced Form Builder

```php
use Filament\Forms\Components\Actions\Action;
use Filament\Forms\Set;
use Filament\Forms\Get;

Forms\Components\Section::make('Post Details')
    ->description('Enter the basic information about your post')
    ->schema([
        Forms\Components\TextInput::make('title')
            ->required()
            ->live(onBlur: true)
            ->afterStateUpdated(function (Set $set, ?string $state) {
                $set('slug', Str::slug($state));
            })
            ->suffixAction(
                Action::make('generate')
                    ->icon('heroicon-m-sparkles')
                    ->action(function (Set $set) {
                        $set('title', fake()->sentence());
                    })
            ),
        
        Forms\Components\Textarea::make('excerpt')
            ->rows(3)
            ->maxLength(500)
            ->helperText('A brief summary of the post')
            ->live()
            ->afterStateUpdated(fn ($state, Set $set) => 
                $set('character_count', strlen($state))
            ),
        
        Forms\Components\Placeholder::make('character_count')
            ->content(fn (Get $get): string => 
                strlen($get('excerpt') ?? '') . ' / 500 characters'
            ),
    ])
    ->columns(2)
    ->collapsible()
    ->persistCollapsed()
    ->compact();

// Split Layout (v5 feature)
Forms\Components\Split::make([
    Forms\Components\Section::make([
        Forms\Components\RichEditor::make('content')
            ->required(),
    ])
    ->grow(),
    
    Forms\Components\Section::make([
        Forms\Components\FileUpload::make('featured_image')
            ->image()
            ->imageEditor(),
        
        Forms\Components\Select::make('categories')
            ->multiple()
            ->relationship('categories', 'name'),
    ])
    ->grow(false),
])->from('md');
```

### New Field Types (v5)

```php
// ColorPicker with swatches
Forms\Components\ColorPicker::make('brand_color')
    ->rgba(),

// Toggle with icons
Forms\Components\Toggle::make('is_featured')
    ->onIcon('heroicon-m-star')
    ->offIcon('heroicon-m-star')
    ->onColor('warning'),

// Radio with descriptions
Forms\Components\Radio::make('visibility')
    ->options([
        'public' => 'Public',
        'private' => 'Private',
    ])
    ->descriptions([
        'public' => 'Everyone can see this post',
        'private' => 'Only you can see this post',
    ]),

// TagsInput with suggestions
Forms\Components\TagsInput::make('keywords')
    ->suggestions([
        'laravel',
        'php',
        'filament',
    ])
    ->reorderable(),

// Wizard for multi-step forms
Forms\Components\Wizard::make([
    Forms\Components\Wizard\Step::make('Content')
        ->schema([
            Forms\Components\TextInput::make('title'),
            Forms\Components\RichEditor::make('content'),
        ]),
    
    Forms\Components\Wizard\Step::make('Settings')
        ->schema([
            Forms\Components\Select::make('status'),
            Forms\Components\DateTimePicker::make('published_at'),
        ]),
    
    Forms\Components\Wizard\Step::make('SEO')
        ->schema([
            Forms\Components\TextInput::make('meta_title'),
            Forms\Components\Textarea::make('meta_description'),
        ]),
])
->columnSpanFull()
->submitAction(new HtmlString('<button type="submit">Submit</button>')),
```

### Conditional Logic (v5 Improved)

```php
Forms\Components\Select::make('post_type')
    ->options([
        'article' => 'Article',
        'video' => 'Video',
        'gallery' => 'Gallery',
    ])
    ->live()
    ->required(),

// Show/hide based on selection
Forms\Components\TextInput::make('video_url')
    ->url()
    ->visible(fn (Get $get): bool => $get('post_type') === 'video')
    ->required(fn (Get $get): bool => $get('post_type') === 'video'),

Forms\Components\Repeater::make('gallery_images')
    ->schema([
        Forms\Components\FileUpload::make('image')
            ->image()
            ->required(),
    ])
    ->visible(fn (Get $get): bool => $get('post_type') === 'gallery')
    ->minItems(1)
    ->maxItems(10),

// Complex conditionals
Forms\Components\Group::make()
    ->schema([
        Forms\Components\TextInput::make('discount_percentage'),
        Forms\Components\DateTimePicker::make('discount_expires_at'),
    ])
    ->visible(fn (Get $get): bool => 
        $get('has_discount') && $get('status') === 'published'
    )
    ->columns(2),
```

## Table Components v5

### Enhanced Table Builder

```php
public static function table(Table $table): Table
{
    return $table
        ->columns([
            Tables\Columns\ImageColumn::make('featured_image')
                ->disk('public')
                ->height(50)
                ->square()
                ->defaultImageUrl(url('/images/placeholder.png')),
            
            Tables\Columns\TextColumn::make('title')
                ->searchable()
                ->sortable()
                ->limit(50)
                ->tooltip(function (TextColumn $column): ?string {
                    $state = $column->getState();
                    if (strlen($state) <= 50) {
                        return null;
                    }
                    return $state;
                })
                ->description(fn (Post $record): string => $record->excerpt),
            
            Tables\Columns\TextColumn::make('author.name')
                ->searchable(query: function (Builder $query, string $search): Builder {
                    return $query->whereHas('author', fn ($q) => 
                        $q->where('name', 'like', "%{$search}%")
                    );
                })
                ->badge()
                ->color('info'),
            
            Tables\Columns\SelectColumn::make('status')
                ->options([
                    'draft' => 'Draft',
                    'reviewing' => 'Reviewing',
                    'published' => 'Published',
                ])
                ->selectablePlaceholder(false),
            
            Tables\Columns\IconColumn::make('is_featured')
                ->boolean()
                ->trueIcon('heroicon-o-star')
                ->falseIcon('heroicon-o-star')
                ->trueColor('warning')
                ->falseColor('gray'),
            
            Tables\Columns\TextColumn::make('views_count')
                ->counts('views')
                ->sortable()
                ->numeric()
                ->alignEnd(),
            
            Tables\Columns\TextColumn::make('created_at')
                ->dateTime()
                ->since()
                ->sortable()
                ->toggleable(),
        ])
        ->filters([
            Tables\Filters\SelectFilter::make('status')
                ->multiple()
                ->options([
                    'draft' => 'Draft',
                    'reviewing' => 'Reviewing',
                    'published' => 'Published',
                ])
                ->indicator('Status'),
            
            Tables\Filters\Filter::make('is_featured')
                ->label('Featured Only')
                ->query(fn (Builder $query): Builder => $query->where('is_featured', true))
                ->toggle(),
            
            Tables\Filters\Filter::make('created_at')
                ->form([
                    Forms\Components\DatePicker::make('created_from')
                        ->label('Created from'),
                    Forms\Components\DatePicker::make('created_until')
                        ->label('Created until'),
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
                })
                ->indicateUsing(function (array $data): array {
                    $indicators = [];
                    if ($data['created_from'] ?? null) {
                        $indicators['created_from'] = 'Created from ' . Carbon::parse($data['created_from'])->toFormattedDateString();
                    }
                    if ($data['created_until'] ?? null) {
                        $indicators['created_until'] = 'Created until ' . Carbon::parse($data['created_until'])->toFormattedDateString();
                    }
                    return $indicators;
                }),
            
            Tables\Filters\TrashedFilter::make(),
        ])
        ->filtersFormColumns(3)
        ->persistFiltersInSession()
        ->actions([
            Tables\Actions\ActionGroup::make([
                Tables\Actions\ViewAction::make(),
                Tables\Actions\EditAction::make(),
                Tables\Actions\ReplicateAction::make()
                    ->excludeAttributes(['slug']),
                Tables\Actions\DeleteAction::make(),
                Tables\Actions\ForceDeleteAction::make(),
                Tables\Actions\RestoreAction::make(),
            ]),
        ])
        ->bulkActions([
            Tables\Actions\BulkActionGroup::make([
                Tables\Actions\BulkAction::make('publish')
                    ->icon('heroicon-o-check')
                    ->requiresConfirmation()
                    ->action(fn (Collection $records) => 
                        $records->each->update(['status' => 'published'])
                    )
                    ->deselectRecordsAfterCompletion(),
                
                Tables\Actions\DeleteBulkAction::make(),
                Tables\Actions\ForceDeleteBulkAction::make(),
                Tables\Actions\RestoreBulkAction::make(),
            ]),
        ])
        ->emptyStateActions([
            Tables\Actions\CreateAction::make(),
        ])
        ->defaultSort('created_at', 'desc')
        ->persistSearchInSession()
        ->striped()
        ->paginated([10, 25, 50, 100]);
}
```

### Advanced Table Features (v5)

```php
// Grouping
->groups([
    Tables\Grouping\Group::make('status')
        ->label('Status')
        ->collapsible(),
    
    Tables\Grouping\Group::make('author.name')
        ->label('Author')
        ->titlePrefixedWithLabel(false),
])

// Summarizers
Tables\Columns\TextColumn::make('views')
    ->numeric()
    ->summarize([
        Tables\Columns\Summarizers\Sum::make()
            ->label('Total views'),
        Tables\Columns\Summarizers\Average::make()
            ->label('Avg views')
            ->numeric(decimalPlaces: 0),
        Tables\Columns\Summarizers\Range::make()
            ->label('Views range'),
    ])

// Column toggles with groups
->toggleColumnsTriggerAction(
    fn (Action $action) => $action
        ->button()
        ->label('Columns')
)

// Custom empty state
->emptyStateHeading('No posts yet')
->emptyStateDescription('Start by creating your first post.')
->emptyStateIcon('heroicon-o-document-text')
->emptyStateActions([
    Tables\Actions\CreateAction::make()
        ->label('Create post'),
])

// Record URLs
->recordUrl(
    fn (Post $record): string => PostResource::getUrl('edit', ['record' => $record])
)

// Or disable record click
->recordUrl(null)
```

## Actions v5

### Enhanced Actions

```php
use Filament\Notifications\Notification;

// Modal action with form
Tables\Actions\Action::make('schedule')
    ->icon('heroicon-o-clock')
    ->form([
        Forms\Components\DateTimePicker::make('scheduled_at')
            ->label('Schedule for')
            ->required()
            ->minDate(now())
            ->native(false),
        
        Forms\Components\Toggle::make('send_notification')
            ->label('Notify subscribers')
            ->default(true),
    ])
    ->action(function (Post $record, array $data): void {
        $record->update([
            'status' => 'scheduled',
            'published_at' => $data['scheduled_at'],
        ]);
        
        if ($data['send_notification']) {
            // Dispatch notification job
        }
        
        Notification::make()
            ->title('Post scheduled')
            ->body("Will be published on {$data['scheduled_at']}")
            ->success()
            ->send();
    })
    ->visible(fn (Post $record): bool => $record->status === 'draft')
    ->successRedirectUrl(route('filament.admin.resources.posts.index'))
    ->closeModalByClickingAway(false)
    ->modalWidth('md'),

// Confirmation with dynamic content
Tables\Actions\DeleteAction::make()
    ->requiresConfirmation()
    ->modalHeading(fn (Post $record) => "Delete {$record->title}?")
    ->modalDescription('This action cannot be undone.')
    ->modalSubmitActionLabel('Yes, delete it')
    ->successNotification(
        Notification::make()
            ->success()
            ->title('Post deleted')
            ->body('The post has been deleted successfully.')
    ),

// Action with slide over
Tables\Actions\Action::make('preview')
    ->icon('heroicon-o-eye')
    ->modalContent(fn (Post $record): View => view(
        'filament.resources.posts.preview',
        ['record' => $record],
    ))
    ->modalSubmitAction(false)
    ->modalCancelActionLabel('Close')
    ->slideOver()
    ->modalWidth('2xl'),

// Header action with authorization
Tables\Actions\Action::make('import')
    ->label('Import posts')
    ->icon('heroicon-o-arrow-up-tray')
    ->form([
        Forms\Components\FileUpload::make('file')
            ->label('CSV file')
            ->acceptedFileTypes(['text/csv'])
            ->required(),
    ])
    ->action(function (array $data): void {
        // Import logic
    })
    ->visible(fn (): bool => auth()->user()->can('import_posts'))
    ->color('gray'),
```

### Bulk Actions (v5)

```php
Tables\Actions\BulkAction::make('updateCategory')
    ->label('Update category')
    ->icon('heroicon-o-tag')
    ->form([
        Forms\Components\Select::make('category_id')
            ->label('Category')
            ->options(Category::pluck('name', 'id'))
            ->required()
            ->searchable(),
    ])
    ->action(function (Collection $records, array $data): void {
        $records->each(fn ($record) => 
            $record->update(['category_id' => $data['category_id']])
        );
        
        Notification::make()
            ->title('Categories updated')
            ->success()
            ->send();
    })
    ->deselectRecordsAfterCompletion()
    ->requiresConfirmation(),

// Export bulk action
Tables\Actions\BulkAction::make('export')
    ->label('Export selected')
    ->icon('heroicon-o-arrow-down-tray')
    ->action(function (Collection $records): void {
        return response()->download(
            Excel::store(new PostsExport($records), 'posts.xlsx'),
            'posts.xlsx'
        );
    })
    ->deselectRecordsAfterCompletion(false),
```

## Relation Managers v5

```php
namespace App\Filament\Resources\PostResource\RelationManagers;

use Filament\Forms;
use Filament\Forms\Form;
use Filament\Resources\RelationManagers\RelationManager;
use Filament\Tables;
use Filament\Tables\Table;

class CommentsRelationManager extends RelationManager
{
    protected static string $relationship = 'comments';
    
    protected static ?string $recordTitleAttribute = 'content';
    
    public function form(Form $form): Form
    {
        return $form
            ->schema([
                Forms\Components\Textarea::make('content')
                    ->required()
                    ->rows(3)
                    ->maxLength(500),
                
                Forms\Components\Select::make('status')
                    ->options([
                        'pending' => 'Pending',
                        'approved' => 'Approved',
                        'spam' => 'Spam',
                    ])
                    ->default('pending')
                    ->required(),
            ])
            ->columns(1);
    }
    
    public function table(Table $table): Table
    {
        return $table
            ->recordTitleAttribute('content')
            ->columns([
                Tables\Columns\TextColumn::make('author.name')
                    ->label('Author')
                    ->searchable()
                    ->sortable(),
                
                Tables\Columns\TextColumn::make('content')
                    ->limit(50)
                    ->searchable()
                    ->wrap(),
                
                Tables\Columns\SelectColumn::make('status')
                    ->options([
                        'pending' => 'Pending',
                        'approved' => 'Approved',
                        'spam' => 'Spam',
                    ]),
                
                Tables\Columns\TextColumn::make('created_at')
                    ->dateTime()
                    ->since()
                    ->sortable(),
            ])
            ->filters([
                Tables\Filters\SelectFilter::make('status')
                    ->options([
                        'pending' => 'Pending',
                        'approved' => 'Approved',
                        'spam' => 'Spam',
                    ]),
            ])
            ->headerActions([
                Tables\Actions\CreateAction::make()
                    ->mutateFormDataUsing(function (array $data): array {
                        $data['author_id'] = auth()->id();
                        return $data;
                    }),
            ])
            ->actions([
                Tables\Actions\ActionGroup::make([
                    Tables\Actions\EditAction::make(),
                    Tables\Actions\DeleteAction::make(),
                    Tables\Actions\Action::make('approve')
                        ->icon('heroicon-o-check')
                        ->action(fn ($record) => $record->update(['status' => 'approved']))
                        ->visible(fn ($record) => $record->status !== 'approved'),
                ]),
            ])
            ->bulkActions([
                Tables\Actions\BulkActionGroup::make([
                    Tables\Actions\DeleteBulkAction::make(),
                ]),
            ])
            ->modifyQueryUsing(fn ($query) => $query->with('author'))
            ->defaultSort('created_at', 'desc');
    }
}
```

## Custom Pages v5

```php
namespace App\Filament\Resources\PostResource\Pages;

use App\Filament\Resources\PostResource;
use Filament\Actions;
use Filament\Resources\Pages\EditRecord;

class EditPost extends EditRecord
{
    protected static string $resource = PostResource::class;
    
    protected function getHeaderActions(): array
    {
        return [
            Actions\ViewAction::make(),
            
            Actions\Action::make('preview')
                ->url(fn (Post $record): string => route('posts.show', $record))
                ->openUrlInNewTab()
                ->icon('heroicon-o-eye'),
            
            Actions\DeleteAction::make(),
            
            Actions\ForceDeleteAction::make(),
            
            Actions\RestoreAction::make(),
        ];
    }
    
    protected function getFormActions(): array
    {
        return [
            $this->getSaveFormAction()
                ->submit(null)
                ->action('save'),
            
            Actions\Action::make('saveAndPublish')
                ->label('Save & Publish')
                ->action('saveAndPublish')
                ->color('success')
                ->keyBindings(['mod+s']),
            
            $this->getCancelFormAction(),
        ];
    }
    
    public function saveAndPublish(): void
    {
        $this->data['status'] = 'published';
        $this->data['published_at'] = now();
        
        $this->save();
    }
    
    protected function mutateFormDataBeforeSave(array $data): array
    {
        $data['updated_by'] = auth()->id();
        
        return $data;
    }
    
    protected function afterSave(): void
    {
        Notification::make()
            ->title('Post updated')
            ->success()
            ->send();
    }
}
```

## Widgets v5

```php
namespace App\Filament\Widgets;

use Filament\Widgets\StatsOverviewWidget as BaseWidget;
use Filament\Widgets\StatsOverviewWidget\Stat;
use App\Models\Post;

class PostStatsOverview extends BaseWidget
{
    protected static ?int $sort = 1;
    
    protected static ?string $pollingInterval = '30s';
    
    protected function getStats(): array
    {
        return [
            Stat::make('Total Posts', Post::count())
                ->description('All time posts')
                ->descriptionIcon('heroicon-m-arrow-trending-up')
                ->chart([7, 2, 10, 3, 15, 4, 17])
                ->color('success'),
            
            Stat::make('Published', Post::where('status', 'published')->count())
                ->description('7% increase')
                ->descriptionIcon('heroicon-m-arrow-trending-up')
                ->color('info'),
            
            Stat::make('Draft', Post::where('status', 'draft')->count())
                ->description('Pending publication')
                ->descriptionIcon('heroicon-m-pencil')
                ->color('warning'),
            
            Stat::make('Views', Post::sum('views_count'))
                ->description('Last 30 days')
                ->descriptionIcon('heroicon-m-eye')
                ->chart([40, 50, 60, 70, 65, 80, 100])
                ->color('primary'),
        ];
    }
}

// Chart Widget
namespace App\Filament\Widgets;

use Filament\Widgets\ChartWidget;
use Flowframe\Trend\Trend;
use Flowframe\Trend\TrendValue;
use App\Models\Post;

class PostsChart extends ChartWidget
{
    protected static ?string $heading = 'Posts Created';
    
    protected static ?int $sort = 2;
    
    protected static string $color = 'info';
    
    public ?string $filter = 'month';
    
    protected function getData(): array
    {
        $activeFilter = $this->filter;
        
        $data = match ($activeFilter) {
            'week' => Trend::model(Post::class)
                ->between(
                    start: now()->subWeek(),
                    end: now(),
                )
                ->perDay()
                ->count(),
            'month' => Trend::model(Post::class)
                ->between(
                    start: now()->subMonth(),
                    end: now(),
                )
                ->perDay()
                ->count(),
            'year' => Trend::model(Post::class)
                ->between(
                    start: now()->subYear(),
                    end: now(),
                )
                ->perMonth()
                ->count(),
        };
        
        return [
            'datasets' => [
                [
                    'label' => 'Posts',
                    'data' => $data->map(fn (TrendValue $value) => $value->aggregate),
                ],
            ],
            'labels' => $data->map(fn (TrendValue $value) => $value->date),
        ];
    }
    
    protected function getType(): string
    {
        return 'line';
    }
    
    protected function getFilters(): ?array
    {
        return [
            'week' => 'Last week',
            'month' => 'Last month',
            'year' => 'Last year',
        ];
    }
}

// Table Widget
namespace App\Filament\Widgets;

use Filament\Tables;
use Filament\Tables\Table;
use Filament\Widgets\TableWidget as BaseWidget;
use App\Models\Post;

class LatestPosts extends BaseWidget
{
    protected static ?int $sort = 3;
    
    protected int | string | array $columnSpan = 'full';
    
    public function table(Table $table): Table
    {
        return $table
            ->query(
                Post::query()
                    ->latest()
                    ->limit(5)
            )
            ->columns([
                Tables\Columns\TextColumn::make('title')
                    ->searchable(),
                
                Tables\Columns\TextColumn::make('author.name')
                    ->badge(),
                
                Tables\Columns\TextColumn::make('status')
                    ->badge()
                    ->color(fn (string $state): string => match ($state) {
                        'draft' => 'gray',
                        'reviewing' => 'warning',
                        'published' => 'success',
                    }),
                
                Tables\Columns\TextColumn::make('created_at')
                    ->since()
                    ->sortable(),
            ]);
    }
}
```

## Info Lists v5 (New Feature)

```php
use Filament\Infolists\Components;
use Filament\Infolists\Infolist;

// In ViewPost page
public function infolist(Infolist $infolist): Infolist
{
    return $infolist
        ->schema([
            Components\Section::make('Post Information')
                ->schema([
                    Components\Split::make([
                        Components\Grid::make(2)
                            ->schema([
                                Components\TextEntry::make('title'),
                                
                                Components\TextEntry::make('slug')
                                    ->badge()
                                    ->copyable(),
                                
                                Components\TextEntry::make('status')
                                    ->badge()
                                    ->color(fn (string $state): string => match ($state) {
                                        'draft' => 'gray',
                                        'reviewing' => 'warning',
                                        'published' => 'success',
                                    }),
                                
                                Components\TextEntry::make('author.name')
                                    ->label('Author'),
                            ]),
                        
                        Components\ImageEntry::make('featured_image')
                            ->hiddenLabel()
                            ->grow(false),
                    ])->from('lg'),
                ])
                ->collapsible(),
            
            Components\Section::make('Content')
                ->schema([
                    Components\TextEntry::make('content')
                        ->prose()
                        ->markdown()
                        ->hiddenLabel(),
                ])
                ->collapsible(),
            
            Components\Section::make('Metadata')
                ->schema([
                    Components\TextEntry::make('created_at')
                        ->dateTime(),
                    
                    Components\TextEntry::make('updated_at')
                        ->dateTime()
                        ->since(),
                    
                    Components\TextEntry::make('published_at')
                        ->dateTime()
                        ->placeholder('Not published'),
                ])
                ->columns(3),
            
            Components\Section::make('Tags')
                ->schema([
                    Components\TextEntry::make('tags')
                        ->badge()
                        ->separator(','),
                ]),
        ]);
}
```

## Global Search v5

```php
// In Resource
protected static ?string $recordTitleAttribute = 'title';

public static function getGlobalSearchResultTitle(Model $record): string | Htmlable
{
    return $record->title;
}

public static function getGloballySearchableAttributes(): array
{
    return ['title', 'slug', 'content', 'author.name'];
}

public static function getGlobalSearchResultDetails(Model $record): array
{
    return [
        'Author' => $record->author->name,
        'Status' => $record->status,
        'Published' => $record->published_at?->diffForHumans() ?? 'Not published',
    ];
}

public static function getGlobalSearchResultUrl(Model $record): string
{
    return PostResource::getUrl('edit', ['record' => $record]);
}

public static function getGlobalSearchResultActions(Model $record): array
{
    return [
        Action::make('edit')
            ->url(PostResource::getUrl('edit', ['record' => $record])),
        
        Action::make('view')
            ->url(PostResource::getUrl('view', ['record' => $record])),
    ];
}

// Limit search results
public static function getGlobalSearchEloquentQuery(): Builder
{
    return parent::getGlobalSearchEloquentQuery()
        ->with(['author'])
        ->where('status', 'published');
}
```

## Authorization v5

```php
// Policy with all methods
class PostPolicy
{
    public function viewAny(User $user): bool
    {
        return $user->can('view_any_post');
    }
    
    public function view(User $user, Post $post): bool
    {
        return $user->can('view_post');
    }
    
    public function create(User $user): bool
    {
        return $user->can('create_post');
    }
    
    public function update(User $user, Post $post): bool
    {
        return $user->can('update_post') || $post->author_id === $user->id;
    }
    
    public function delete(User $user, Post $post): bool
    {
        return $user->can('delete_post');
    }
    
    public function deleteAny(User $user): bool
    {
        return $user->can('delete_any_post');
    }
    
    public function forceDelete(User $user, Post $post): bool
    {
        return $user->can('force_delete_post');
    }
    
    public function forceDeleteAny(User $user): bool
    {
        return $user->can('force_delete_any_post');
    }
    
    public function restore(User $user, Post $post): bool
    {
        return $user->can('restore_post');
    }
    
    public function restoreAny(User $user): bool
    {
        return $user->can('restore_any_post');
    }
    
    public function replicate(User $user, Post $post): bool
    {
        return $user->can('replicate_post');
    }
    
    public function reorder(User $user): bool
    {
        return $user->can('reorder_post');
    }
}

// In Resource - conditional navigation
public static function shouldRegisterNavigation(): bool
{
    return auth()->user()->can('view_any_post');
}

// Conditional page access
public static function canAccess(): bool
{
    return auth()->user()->hasRole('admin');
}
```

## Performance Optimization v5

### Lazy Loading

```php
// Resource navigation badge
protected static ?string $navigationBadge = null;

public static function getNavigationBadge(): ?string
{
    // Cache for 5 minutes
    return Cache::remember('posts_count', 300, function () {
        return static::getModel()::count();
    });
}

// Defer heavy widgets
class HeavyWidget extends Widget
{
    protected static bool $isLazy = true;
    
    protected static ?string $loadingIndicator = 'Loading statistics...';
}

// Optimize table queries
public static function table(Table $table): Table
{
    return $table
        ->modifyQueryUsing(function (Builder $query) {
            return $query
                ->with(['author', 'category'])
                ->withCount('comments');
        })
        ->deferLoading()
        ->persistFiltersInSession()
        ->persistSearchInSession();
}

// Use computed properties with caching
use Filament\Infolists\Components\TextEntry;

TextEntry::make('expensive_calculation')
    ->state(function (Post $record): string {
        return Cache::remember(
            "post.{$record->id}.calculation",
            now()->addHour(),
            fn () => $this->performExpensiveCalculation($record)
        );
    }),
```

### Database Optimization

```php
// Eager load relationships
protected static function getEloquentQuery(): Builder
{
    return parent::getEloquentQuery()
        ->with(['author', 'category'])
        ->withCount(['comments', 'views']);
}

// Add indexes to searchable/sortable columns
Schema::table('posts', function (Blueprint $table) {
    $table->index('title');
    $table->index('status');
    $table->index(['author_id', 'created_at']);
});

// Use specific columns in selects
public static function table(Table $table): Table
{
    return $table
        ->modifyQueryUsing(fn (Builder $query) => 
            $query->select([
                'posts.*',
                DB::raw('(SELECT COUNT(*) FROM comments WHERE post_id = posts.id) as comments_count')
            ])
        );
}
```

## Testing v5

```php
use function Pest\Livewire\livewire;

test('can render list posts page', function () {
    livewire(PostResource\Pages\ListPosts::class)
        ->assertSuccessful();
});

test('can create post', function () {
    $author = User::factory()->create();
    
    livewire(PostResource\Pages\CreatePost::class)
        ->fillForm([
            'title' => 'Test Post',
            'slug' => 'test-post',
            'content' => 'Test content',
            'status' => 'draft',
            'author_id' => $author->id,
        ])
        ->call('create')
        ->assertHasNoFormErrors();
    
    expect(Post::where('slug', 'test-post')->first())
        ->title->toBe('Test Post')
        ->status->toBe('draft');
});

test('can edit post', function () {
    $post = Post::factory()->create();
    
    livewire(PostResource\Pages\EditPost::class, [
        'record' => $post->getRouteKey(),
    ])
        ->fillForm([
            'title' => 'Updated Title',
        ])
        ->call('save')
        ->assertHasNoFormErrors();
    
    expect($post->fresh())
        ->title->toBe('Updated Title');
});

test('can validate form', function () {
    livewire(PostResource\Pages\CreatePost::class)
        ->fillForm([
            'title' => '',
        ])
        ->call('create')
        ->assertHasFormErrors(['title' => 'required']);
});

test('can search posts', function () {
    $posts = Post::factory()->count(3)->create();
    
    livewire(PostResource\Pages\ListPosts::class)
        ->searchTable($posts[0]->title)
        ->assertCanSeeTableRecords([$posts[0]])
        ->assertCanNotSeeTableRecords([$posts[1], $posts[2]]);
});

test('can filter posts by status', function () {
    $draft = Post::factory()->create(['status' => 'draft']);
    $published = Post::factory()->create(['status' => 'published']);
    
    livewire(PostResource\Pages\ListPosts::class)
        ->filterTable('status', 'draft')
        ->assertCanSeeTableRecords([$draft])
        ->assertCanNotSeeTableRecords([$published]);
});

test('can delete post', function () {
    $post = Post::factory()->create();
    
    livewire(PostResource\Pages\EditPost::class, [
        'record' => $post->getRouteKey(),
    ])
        ->callAction('delete');
    
    expect($post->fresh())
        ->trashed()->toBeTrue();
});
```

## Common Patterns v5

### Dynamic Options

```php
Forms\Components\Select::make('state_id')
    ->options(fn (Get $get): array => 
        State::where('country_id', $get('country_id'))
            ->pluck('name', 'id')
            ->toArray()
    )
    ->searchable()
    ->preload()
    ->required(),
```

### Repeater with Relationship

```php
Forms\Components\Repeater::make('items')
    ->relationship()
    ->schema([
        Forms\Components\Select::make('product_id')
            ->relationship('product', 'name')
            ->required()
            ->distinct()
            ->disableOptionsWhenSelectedInSiblingRepeaterItems()
            ->searchable()
            ->preload(),
        
        Forms\Components\TextInput::make('quantity')
            ->numeric()
            ->default(1)
            ->required(),
        
        Forms\Components\TextInput::make('price')
            ->numeric()
            ->prefix('€')
            ->disabled()
            ->dehydrated()
            ->afterStateHydrated(function ($state, $set, $get) {
                $product = Product::find($get('product_id'));
                $set('price', $product?->price);
            }),
    ])
    ->columns(3)
    ->defaultItems(1)
    ->reorderable()
    ->collapsible()
    ->itemLabel(fn (array $state): ?string => 
        Product::find($state['product_id'])?->name
    )
    ->addActionLabel('Add item'),
```

### File Upload with Processing

```php
Forms\Components\FileUpload::make('images')
    ->image()
    ->multiple()
    ->reorderable()
    ->appendFiles()
    ->maxSize(5120)
    ->acceptedFileTypes(['image/jpeg', 'image/png', 'image/webp'])
    ->imageEditor()
    ->imageEditorAspectRatios([
        '16:9',
        '4:3',
        '1:1',
    ])
    ->imageCropAspectRatio('16:9')
    ->imageResizeTargetWidth(1920)
    ->imageResizeTargetHeight(1080)
    ->optimize('webp')
    ->disk('public')
    ->directory('posts/images')
    ->visibility('public')
    ->downloadable()
    ->openable()
    ->previewable()
    ->columnSpanFull(),
```

## Troubleshooting v5

**Common Issues**:

1. **Livewire 3 migration issues**
   - Use `live()` instead of `reactive()`
   - Replace `wire:model.defer` with `wire:model.blur`
   - Update `$listeners` to use `#[On]` attribute

2. **Performance issues**
   - Enable `deferLoading()` on tables
   - Use lazy loading for widgets
   - Optimize queries with proper indexes
   - Cache expensive calculations

3. **Form not updating**
   - Check `live()` configuration
   - Verify closure parameters (Get, Set)
   - Use `afterStateUpdated()` correctly

4. **Table filters not working**
   - Verify `persistFiltersInSession()`
   - Check filter query logic
   - Ensure proper array structure

5. **Authorization failures**
   - Register policies in AuthServiceProvider
   - Check all policy methods
   - Verify gate definitions

## Best Practices v5

1. **Type Everything**: Use PHP 8.1+ features (enums, attributes, typed properties)
2. **Optimize Queries**: Always eager load relationships, use indexes
3. **Cache Smart**: Cache expensive operations, navigation badges, calculations
4. **Test Everything**: Write tests for resources, actions, and custom logic
5. **Component Reuse**: Extract repeated form schemas into reusable components
6. **Authorization**: Always implement and test policies
7. **Validation**: Validate on both client and server side
8. **Performance**: Use lazy loading, pagination, and deferred rendering
9. **UX**: Provide loading states, success messages, and clear error handling
10. **Code Organization**: Keep resources focused, extract complex logic to actions

## Migration from v3 to v5

```php
// v3 (Old)
->reactive()
->afterStateUpdated(fn ($state, callable $set) => ...)

// v5 (New)
->live(onBlur: true)
->afterStateUpdated(fn ($state, Set $set) => ...)

// v3 (Old)
Tables\Columns\BadgeColumn::make('status')

// v5 (New)
Tables\Columns\TextColumn::make('status')
    ->badge()

// v3 (Old)
protected function getTableQuery(): Builder

// v5 (New)
->modifyQueryUsing(fn (Builder $query) => ...)

// v3 (Old)
protected function getActions(): array

// v5 (New)
protected function getHeaderActions(): array
```

## Quick Commands

```bash
# Install Filament v5
composer require filament/filament:"^5.0"

# Create Resource
php artisan make:filament-resource Post --generate --view

# Create Relation Manager
php artisan make:filament-relation-manager PostResource comments content

# Create Custom Page
php artisan make:filament-page Settings

# Create Widget
php artisan make:filament-widget PostsChart --chart

# Clear cache
php artisan filament:optimize-clear
```
