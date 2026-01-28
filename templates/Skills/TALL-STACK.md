---
name: tall-stack
description: Expert guidance for building modern web applications with TALL Stack (Tailwind CSS, Alpine.js, Laravel, Livewire). Use when creating interactive UIs, implementing Livewire components, Alpine.js interactions, Laravel backend logic, or building full-stack applications. Covers component architecture, state management, real-time features, forms, validation, and performance optimization.
---

# TALL Stack Expert

Expert guidance for building modern, reactive web applications with Tailwind CSS, Alpine.js, Laravel, and Livewire.

## Stack Overview

**T**ailwind CSS - Utility-first CSS framework
**A**lpine.js - Minimal JavaScript framework for interactivity
**L**aravel - PHP framework for backend
**L**ivewire - Full-stack framework for dynamic interfaces

## Core Principles

**Server-Side Rendering**: Livewire renders on server, sends HTML to client
**Reactive Components**: State changes trigger automatic re-renders
**Progressive Enhancement**: Start with HTML, enhance with Alpine.js
**Component-Driven**: Build reusable, self-contained components

## Livewire Components

### Basic Component Structure

```php
// app/Livewire/PostList.php
namespace App\Livewire;

use Livewire\Component;
use Livewire\WithPagination;
use App\Models\Post;

class PostList extends Component
{
    use WithPagination;
    
    public string $search = '';
    public string $sortBy = 'created_at';
    public string $sortDirection = 'desc';
    
    public function updatedSearch()
    {
        $this->resetPage();
    }
    
    public function sortBy($field)
    {
        if ($this->sortBy === $field) {
            $this->sortDirection = $this->sortDirection === 'asc' ? 'desc' : 'asc';
        } else {
            $this->sortBy = $field;
            $this->sortDirection = 'asc';
        }
    }
    
    public function render()
    {
        return view('livewire.post-list', [
            'posts' => Post::query()
                ->when($this->search, fn($q) => $q->where('title', 'like', "%{$this->search}%"))
                ->orderBy($this->sortBy, $this->sortDirection)
                ->paginate(10),
        ]);
    }
}
```

```blade
{{-- resources/views/livewire/post-list.blade.php --}}
<div>
    <div class="mb-4">
        <input 
            type="text" 
            wire:model.live.debounce.300ms="search"
            placeholder="Search posts..."
            class="rounded-lg border-gray-300 w-full"
        >
    </div>

    <div class="space-y-4">
        @foreach($posts as $post)
            <div class="bg-white rounded-lg shadow p-4">
                <h3 class="text-lg font-semibold">{{ $post->title }}</h3>
                <p class="text-gray-600">{{ $post->excerpt }}</p>
                
                <button 
                    wire:click="$dispatch('edit-post', { postId: {{ $post->id }} })"
                    class="mt-2 text-blue-600 hover:text-blue-800"
                >
                    Edit
                </button>
            </div>
        @endforeach
    </div>

    {{ $posts->links() }}
</div>
```

### Property Binding

```php
// Public properties are automatically available in the view
public string $title = '';
public bool $published = false;
public array $tags = [];

// Protected/private properties are NOT available in view
protected string $internalState = '';

// Computed properties
public function getFullNameProperty()
{
    return $this->firstName . ' ' . $this->lastName;
}
// Usage: {{ $this->fullName }}
```

### Lifecycle Hooks

```php
class EditPost extends Component
{
    public Post $post;
    public string $title;
    
    // Runs once, when component is instantiated
    public function mount(Post $post)
    {
        $this->post = $post;
        $this->title = $post->title;
    }
    
    // Runs on every request, before render
    public function hydrate()
    {
        // Re-establish state after hydration
    }
    
    // Runs before any update
    public function updating($name, $value)
    {
        // Before property update
    }
    
    // Runs after any update
    public function updated($name, $value)
    {
        // After property update
        if ($name === 'title') {
            $this->validate(['title' => 'required|min:3']);
        }
    }
    
    // Runs before render
    public function render()
    {
        return view('livewire.edit-post');
    }
}
```

## Wire Directives

### Data Binding

```blade
{{-- Live binding (updates on every keystroke) --}}
<input type="text" wire:model.live="title">

{{-- Live with debounce (300ms default) --}}
<input type="text" wire:model.live.debounce.500ms="search">

{{-- Blur binding (updates on blur) --}}
<input type="text" wire:model.blur="email">

{{-- Lazy binding (updates on form submit/action) --}}
<input type="text" wire:model="description">

{{-- Bind to nested properties --}}
<input type="text" wire:model="post.title">
```

### Actions

```blade
{{-- Call method --}}
<button wire:click="save">Save</button>

{{-- With parameters --}}
<button wire:click="delete({{ $post->id }})">Delete</button>

{{-- Prevent default --}}
<form wire:submit.prevent="submit">

{{-- Stop propagation --}}
<button wire:click.stop="action">Click</button>

{{-- Modifiers --}}
<button wire:click.debounce.500ms="search">Search</button>
<input wire:keydown.enter="submit">
<input wire:keydown.escape="cancel">
```

### Loading States

```blade
{{-- Show during any wire action --}}
<div wire:loading>
    Processing...
</div>

{{-- Hide during wire action --}}
<div wire:loading.remove>
    Click to submit
</div>

{{-- Target specific action --}}
<button wire:click="save">Save</button>
<div wire:loading wire:target="save">
    Saving...
</div>

{{-- Delay loading indicator --}}
<div wire:loading.delay.shortest>Loading...</div>
<div wire:loading.delay.short>Loading...</div>
<div wire:loading.delay.long>Loading...</div>
<div wire:loading.delay.longer>Loading...</div>

{{-- Class manipulation --}}
<button 
    wire:click="save"
    wire:loading.class="opacity-50"
    wire:loading.attr="disabled"
>
    Save
</button>
```

### Polling

```blade
{{-- Poll every 2 seconds --}}
<div wire:poll.2s>
    Current time: {{ now() }}
</div>

{{-- Poll specific action --}}
<div wire:poll.5s="refreshStats">
    Stats: {{ $stats }}
</div>

{{-- Keep alive (prevent timeout) --}}
<div wire:poll.keep-alive></div>
```

## Forms & Validation

### Basic Form

```php
class CreatePost extends Component
{
    public string $title = '';
    public string $content = '';
    public array $tags = [];
    
    protected function rules()
    {
        return [
            'title' => 'required|min:3|max:255',
            'content' => 'required|min:10',
            'tags' => 'array|max:5',
            'tags.*' => 'string|max:20',
        ];
    }
    
    protected $messages = [
        'title.required' => 'The post title is required.',
        'title.min' => 'The title must be at least 3 characters.',
    ];
    
    public function save()
    {
        $validated = $this->validate();
        
        Post::create($validated);
        
        session()->flash('message', 'Post created successfully!');
        
        return $this->redirect(route('posts.index'));
    }
    
    // Real-time validation on specific field
    public function updated($propertyName)
    {
        $this->validateOnly($propertyName);
    }
}
```

```blade
<form wire:submit.prevent="save">
    <div>
        <label>Title</label>
        <input type="text" wire:model.blur="title">
        @error('title') 
            <span class="text-red-600">{{ $message }}</span> 
        @enderror
    </div>

    <div>
        <label>Content</label>
        <textarea wire:model="content"></textarea>
        @error('content') 
            <span class="text-red-600">{{ $message }}</span> 
        @enderror
    </div>

    <button 
        type="submit"
        wire:loading.attr="disabled"
        wire:loading.class="opacity-50"
    >
        Save Post
    </button>
</form>

@if (session()->has('message'))
    <div class="alert alert-success">
        {{ session('message') }}
    </div>
@endif
```

### Form Objects

```php
// app/Livewire/Forms/PostForm.php
namespace App\Livewire\Forms;

use Livewire\Form;
use App\Models\Post;

class PostForm extends Form
{
    public ?Post $post;
    
    public string $title = '';
    public string $content = '';
    
    public function rules()
    {
        return [
            'title' => 'required|min:3',
            'content' => 'required',
        ];
    }
    
    public function setPost(Post $post)
    {
        $this->post = $post;
        $this->title = $post->title;
        $this->content = $post->content;
    }
    
    public function store()
    {
        $this->validate();
        
        Post::create($this->only(['title', 'content']));
    }
    
    public function update()
    {
        $this->validate();
        
        $this->post->update($this->only(['title', 'content']));
    }
}

// In component
class EditPost extends Component
{
    public PostForm $form;
    
    public function mount(Post $post)
    {
        $this->form->setPost($post);
    }
    
    public function save()
    {
        $this->form->update();
        session()->flash('message', 'Post updated!');
    }
}
```

## File Uploads

```php
use Livewire\WithFileUploads;

class UploadPhoto extends Component
{
    use WithFileUploads;
    
    public $photo;
    public $photos = []; // Multiple files
    
    public function save()
    {
        $this->validate([
            'photo' => 'image|max:1024', // 1MB Max
            'photos.*' => 'image|max:1024',
        ]);
        
        // Store single file
        $path = $this->photo->store('photos', 'public');
        
        // Store multiple files
        foreach ($this->photos as $photo) {
            $photo->store('photos', 'public');
        }
    }
    
    public function removePhoto($index)
    {
        array_splice($this->photos, $index, 1);
    }
}
```

```blade
<form wire:submit.prevent="save">
    {{-- Single file --}}
    <input type="file" wire:model="photo">
    
    @if ($photo)
        <img src="{{ $photo->temporaryUrl() }}" class="w-32 h-32">
    @endif
    
    @error('photo') 
        <span class="text-red-600">{{ $message }}</span> 
    @enderror
    
    {{-- Multiple files --}}
    <input type="file" wire:model="photos" multiple>
    
    @if ($photos)
        <div class="grid grid-cols-4 gap-4">
            @foreach($photos as $index => $photo)
                <div class="relative">
                    <img src="{{ $photo->temporaryUrl() }}" class="w-full">
                    <button 
                        type="button"
                        wire:click="removePhoto({{ $index }})"
                        class="absolute top-0 right-0 bg-red-500 text-white p-1"
                    >
                        ×
                    </button>
                </div>
            @endforeach
        </div>
    @endif
    
    {{-- Upload progress --}}
    <div wire:loading wire:target="photo">
        <div class="w-full bg-gray-200 rounded">
            <div class="bg-blue-600 h-2 rounded" style="width: {{ $uploadProgress }}%"></div>
        </div>
    </div>
    
    <button type="submit">Upload</button>
</form>
```

## Events

### Dispatching Events

```php
// Dispatch to current component
$this->dispatch('post-saved');

// Dispatch with data
$this->dispatch('post-saved', postId: $post->id, title: $post->title);

// Dispatch to specific component
$this->dispatch('post-saved')->to(PostList::class);

// Dispatch to all components
$this->dispatch('post-saved')->to('*');

// Dispatch to parent
$this->dispatch('post-saved')->up();

// Dispatch to children
$this->dispatch('post-saved')->self();

// Dispatch browser event
$this->dispatch('post-saved')->to('browser');
```

### Listening to Events

```php
class PostList extends Component
{
    // Method 1: Protected $listeners array
    protected $listeners = [
        'post-saved' => 'handlePostSaved',
        'post-deleted' => 'refreshPosts',
    ];
    
    public function handlePostSaved($postId, $title)
    {
        // Handle event
    }
    
    public function refreshPosts()
    {
        // Refresh component
    }
}

// Method 2: Livewire\Attributes\On attribute
use Livewire\Attributes\On;

class PostList extends Component
{
    #[On('post-saved')]
    public function handlePostSaved($postId, $title)
    {
        // Handle event
    }
}
```

```blade
{{-- Listen in template --}}
<div 
    x-data
    @post-saved.window="console.log('Post saved!')"
>
    {{-- Or with Livewire --}}
    <button wire:click="$dispatch('refresh-posts')">
        Refresh
    </button>
</div>
```

## Alpine.js Integration

### Basic Alpine Usage

```blade
{{-- Toggle --}}
<div x-data="{ open: false }">
    <button @click="open = !open">Toggle</button>
    <div x-show="open" x-transition>
        Content
    </div>
</div>

{{-- Dropdown --}}
<div x-data="{ open: false }" @click.away="open = false">
    <button @click="open = !open">Menu</button>
    <div x-show="open" x-transition>
        <a href="#">Item 1</a>
        <a href="#">Item 2</a>
    </div>
</div>

{{-- Tabs --}}
<div x-data="{ tab: 'home' }">
    <button @click="tab = 'home'" :class="{ 'active': tab === 'home' }">
        Home
    </button>
    <button @click="tab = 'profile'" :class="{ 'active': tab === 'profile' }">
        Profile
    </button>
    
    <div x-show="tab === 'home'">Home content</div>
    <div x-show="tab === 'profile'">Profile content</div>
</div>
```

### Alpine with Livewire

```blade
{{-- Access Livewire data in Alpine --}}
<div 
    x-data="{ 
        search: @entangle('search'),
        count: @entangle('count').live
    }"
>
    <input type="text" x-model="search">
    <p>Count: <span x-text="count"></span></p>
</div>

{{-- Livewire action from Alpine --}}
<button 
    x-data
    @click="$wire.save()"
>
    Save
</button>

{{-- Access Livewire properties --}}
<div x-data>
    <p x-text="$wire.title"></p>
    <button @click="$wire.title = 'New Title'">Change</button>
</div>
```

### Common Alpine Patterns

```blade
{{-- Modal --}}
<div 
    x-data="{ open: false }"
    @open-modal.window="open = true"
    @keydown.escape.window="open = false"
>
    <button @click="open = true">Open Modal</button>
    
    <div 
        x-show="open"
        x-transition:enter="transition ease-out duration-300"
        x-transition:leave="transition ease-in duration-200"
        class="fixed inset-0 bg-gray-500 bg-opacity-75"
    >
        <div @click.away="open = false" class="bg-white p-6 rounded-lg">
            <h2>Modal Title</h2>
            <button @click="open = false">Close</button>
        </div>
    </div>
</div>

{{-- Tooltip --}}
<div 
    x-data="{ tooltip: false }"
    @mouseenter="tooltip = true"
    @mouseleave="tooltip = false"
    class="relative"
>
    <button>Hover me</button>
    <div 
        x-show="tooltip"
        x-transition
        class="absolute bottom-full mb-2 px-2 py-1 bg-gray-900 text-white rounded text-sm"
    >
        Tooltip text
    </div>
</div>

{{-- Notification --}}
<div 
    x-data="{ 
        show: false, 
        message: '',
        showNotification(msg) {
            this.message = msg;
            this.show = true;
            setTimeout(() => this.show = false, 3000);
        }
    }"
    @notify.window="showNotification($event.detail)"
>
    <div 
        x-show="show"
        x-transition
        class="fixed top-4 right-4 bg-green-500 text-white px-4 py-2 rounded"
        x-text="message"
    ></div>
</div>
```

## Pagination

```php
use Livewire\WithPagination;

class PostList extends Component
{
    use WithPagination;
    
    public string $search = '';
    
    public function updatingSearch()
    {
        $this->resetPage();
    }
    
    public function render()
    {
        return view('livewire.post-list', [
            'posts' => Post::where('title', 'like', "%{$this->search}%")
                ->paginate(10),
        ]);
    }
}
```

```blade
<div>
    <input wire:model.live="search">
    
    @foreach($posts as $post)
        <div>{{ $post->title }}</div>
    @endforeach
    
    {{ $posts->links() }}
    
    {{-- Or custom pagination --}}
    {{ $posts->links('livewire.pagination') }}
</div>
```

## Real-Time Features

### Laravel Echo Integration

```php
// Install Laravel Echo and Pusher
// npm install --save-dev laravel-echo pusher-js

class Notifications extends Component
{
    public $notifications = [];
    
    protected $listeners = ['echo:notifications,NotificationSent' => 'notificationReceived'];
    
    public function mount()
    {
        $this->notifications = auth()->user()->notifications()->latest()->take(5)->get();
    }
    
    public function notificationReceived($notification)
    {
        $this->notifications->prepend($notification);
        $this->dispatch('notification-received');
    }
    
    public function getListeners()
    {
        return [
            "echo-private:users.{$this->user->id},NotificationSent" => 'notificationReceived',
        ];
    }
}
```

### Database Notifications

```php
class NotificationsList extends Component
{
    public function markAsRead($notificationId)
    {
        auth()->user()
            ->notifications()
            ->where('id', $notificationId)
            ->update(['read_at' => now()]);
    }
    
    public function markAllAsRead()
    {
        auth()->user()
            ->unreadNotifications
            ->markAsRead();
    }
    
    public function render()
    {
        return view('livewire.notifications-list', [
            'notifications' => auth()->user()
                ->notifications()
                ->latest()
                ->paginate(10),
        ]);
    }
}
```

## Performance Optimization

### Lazy Loading

```php
// Load component only when visible
<livewire:heavy-component lazy />

// With placeholder
<livewire:heavy-component lazy>
    <div>Loading...</div>
</livewire:heavy-component>
```

### Defer Loading

```blade
{{-- Load after initial page render --}}
<livewire:stats-widget wire:defer />
```

### Query String

```php
class SearchPosts extends Component
{
    #[Url]
    public string $search = '';
    
    #[Url(as: 'q')]
    public string $query = '';
    
    #[Url(except: 'created_at')]
    public string $sort = 'created_at';
    
    // Or using property
    protected $queryString = [
        'search' => ['except' => ''],
        'page' => ['except' => 1],
    ];
}
```

### Computed Properties with Caching

```php
use Livewire\Attributes\Computed;

class PostList extends Component
{
    #[Computed]
    public function posts()
    {
        return Post::with('author')
            ->latest()
            ->get();
    }
    
    // Use in template: $this->posts
    // Cached until component re-renders
}
```

### Optimize Rendering

```php
// Skip render on property update
#[Locked]
public $userId;

// Skip validation on updates
#[Renderless]
public function incrementCount()
{
    $this->count++;
}
```

## Testing

```php
use Livewire\Livewire;

test('can create post', function () {
    Livewire::test(CreatePost::class)
        ->set('title', 'Test Post')
        ->set('content', 'Test content')
        ->call('save')
        ->assertDispatched('post-created')
        ->assertRedirect(route('posts.index'));
    
    $this->assertDatabaseHas('posts', [
        'title' => 'Test Post',
    ]);
});

test('validates title', function () {
    Livewire::test(CreatePost::class)
        ->set('title', 'ab')
        ->call('save')
        ->assertHasErrors(['title' => 'min']);
});

test('can search posts', function () {
    Post::factory()->create(['title' => 'Laravel']);
    Post::factory()->create(['title' => 'Vue']);
    
    Livewire::test(PostList::class)
        ->set('search', 'Laravel')
        ->assertSee('Laravel')
        ->assertDontSee('Vue');
});
```

## Common Patterns

### Master-Detail

```php
// Master (List)
class PostList extends Component
{
    public function selectPost($postId)
    {
        $this->dispatch('post-selected', postId: $postId);
    }
}

// Detail
class PostDetail extends Component
{
    public ?Post $post = null;
    
    #[On('post-selected')]
    public function loadPost($postId)
    {
        $this->post = Post::find($postId);
    }
}
```

### Infinite Scroll

```php
class PostFeed extends Component
{
    public int $page = 1;
    public int $perPage = 10;
    
    public function loadMore()
    {
        $this->page++;
    }
    
    public function render()
    {
        return view('livewire.post-feed', [
            'posts' => Post::latest()
                ->take($this->page * $this->perPage)
                ->get(),
        ]);
    }
}
```

```blade
<div x-data x-intersect="$wire.loadMore()">
    @foreach($posts as $post)
        <div>{{ $post->title }}</div>
    @endforeach
    
    <div wire:loading>Loading more...</div>
</div>
```

### Confirmation Modal

```php
class DeletePost extends Component
{
    public ?int $confirmingDelete = null;
    
    public function confirmDelete($postId)
    {
        $this->confirmingDelete = $postId;
    }
    
    public function delete()
    {
        Post::find($this->confirmingDelete)->delete();
        $this->confirmingDelete = null;
        $this->dispatch('post-deleted');
    }
}
```

```blade
<div>
    @foreach($posts as $post)
        <button wire:click="confirmDelete({{ $post->id }})">
            Delete
        </button>
    @endforeach
    
    {{-- Modal --}}
    <div 
        x-data="{ open: @entangle('confirmingDelete').live }"
        x-show="open"
        @click.away="open = null"
    >
        <p>Are you sure?</p>
        <button wire:click="delete">Confirm</button>
        <button wire:click="$set('confirmingDelete', null)">Cancel</button>
    </div>
</div>
```

## Troubleshooting

**Common Issues**:

1. **Property not updating**
   - Check wire:model vs wire:model.live
   - Verify property is public
   - Check for JavaScript errors

2. **Component not refreshing**
   - Use $this->dispatch('$refresh')
   - Check lifecycle hooks
   - Verify polling configuration

3. **File upload not working**
   - Check WithFileUploads trait
   - Verify storage is configured
   - Check file size limits

4. **Memory issues**
   - Use lazy loading
   - Implement pagination
   - Use computed properties
   - Clear old data

5. **Alpine not working**
   - Check x-data initialization
   - Verify @entangle syntax
   - Check for JavaScript errors

## Best Practices

1. **Component Size**: Keep components focused and small
2. **State Management**: Use public properties for UI state only
3. **Validation**: Validate early with validateOnly()
4. **Events**: Use events for component communication
5. **Performance**: Implement lazy loading and pagination
6. **Security**: Always validate and authorize on server
7. **Testing**: Write tests for critical user flows
8. **Alpine Usage**: Use Alpine for simple, client-side interactions
9. **Tailwind**: Use utility classes, create components for repeated patterns
10. **Code Organization**: Extract complex logic to actions/services

## Quick Commands

```bash
# Create Livewire component
php artisan make:livewire PostList

# Create component in subfolder
php artisan make:livewire Admin/PostList

# Create inline component (no separate view)
php artisan make:livewire Counter --inline

# Create form object
php artisan make:livewire-form PostForm

# Run tests
php artisan test --filter=Livewire
```
