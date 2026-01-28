---
name: frontend-expert
description: Expert in Vue 3 Composition API, PrimeVue components, and backoffice UX patterns. Use for creating components, managing state, integrating with Laravel APIs, building data tables, forms, dashboards, filters, and admin interfaces. Also covers legacy Vue 2 and Quasar for maintenance. Focuses on performance, reusability, and professional admin UI/UX.
---

# Frontend Expert

Expert guidance for Vue 3 + PrimeVue frontend development with backoffice/admin UI specialization.

## Stack Coverage

### Primary Stack
- Vue 3 (Composition API)
- PrimeVue 3+
- Pinia (state management)
- Vue Router 4
- Axios / Fetch API

### Legacy Support
- Vue 2 (Options API)
- Quasar Framework
- Vuex (state management)

## Core Competencies

### 1. Vue 3 Composition API
- Script setup syntax
- Composables for reusable logic
- Reactive state management
- Lifecycle hooks
- Template refs

### 2. PrimeVue Components
- DataTable (complex tables, filters, sorting, pagination)
- Form components (InputText, Dropdown, Calendar, etc.)
- Dialog, Toast, ConfirmDialog
- Menu, Menubar, TieredMenu
- Chart.js integration via PrimeVue
- Theme customization

### 3. Admin UI Patterns
- CRUD interfaces
- Bulk actions
- Advanced filtering
- Data export
- Search and pagination
- Permission-based UI
- Loading states and skeletons

### 4. API Integration
- Axios configuration
- Error handling
- Request interceptors (auth tokens)
- Response transformation
- Loading states

### 5. State Management
- Pinia stores
- Composables vs stores
- When to use global state

## Vue 3 Composition API Patterns

### Basic Component Structure

```vue
<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useToast } from 'primevue/usetoast'

// Props
const props = defineProps({
  userId: {
    type: Number,
    required: true
  }
})

// Emits
const emit = defineEmits(['update', 'delete'])

// Composables
const router = useRouter()
const toast = useToast()

// State
const user = ref(null)
const loading = ref(false)

// Computed
const fullName = computed(() => {
  return `${user.value?.firstName} ${user.value?.lastName}`
})

// Methods
const fetchUser = async () => {
  loading.value = true
  try {
    const response = await axios.get(`/api/users/${props.userId}`)
    user.value = response.data.data
  } catch (error) {
    toast.add({
      severity: 'error',
      summary: 'Error',
      detail: 'Failed to load user',
      life: 3000
    })
  } finally {
    loading.value = false
  }
}

// Lifecycle
onMounted(() => {
  fetchUser()
})
</script>

<template>
  <div v-if="loading">Loading...</div>
  <div v-else-if="user">
    <h2>{{ fullName }}</h2>
    <!-- Component content -->
  </div>
</template>
```

### Composables (Reusable Logic)

```javascript
// composables/useApi.js
import { ref } from 'vue'
import axios from 'axios'

export function useApi() {
  const loading = ref(false)
  const error = ref(null)

  const get = async (url) => {
    loading.value = true
    error.value = null
    try {
      const response = await axios.get(url)
      return response.data
    } catch (err) {
      error.value = err
      throw err
    } finally {
      loading.value = false
    }
  }

  const post = async (url, data) => {
    loading.value = true
    error.value = null
    try {
      const response = await axios.post(url, data)
      return response.data
    } catch (err) {
      error.value = err
      throw err
    } finally {
      loading.value = false
    }
  }

  return { loading, error, get, post }
}

// Usage in component
import { useApi } from '@/composables/useApi'

const { loading, error, get } = useApi()
const users = ref([])

const fetchUsers = async () => {
  try {
    const data = await get('/api/users')
    users.value = data.data
  } catch (err) {
    console.error('Failed to fetch users', err)
  }
}
```

## PrimeVue Component Patterns

### DataTable - Advanced Usage

```vue
<script setup>
import { ref, onMounted } from 'vue'
import DataTable from 'primevue/datatable'
import Column from 'primevue/column'
import Button from 'primevue/button'
import InputText from 'primevue/inputtext'
import { FilterMatchMode } from 'primevue/api'

const users = ref([])
const loading = ref(false)
const selectedUsers = ref([])
const filters = ref({
  global: { value: null, matchMode: FilterMatchMode.CONTAINS },
  name: { value: null, matchMode: FilterMatchMode.CONTAINS },
  email: { value: null, matchMode: FilterMatchMode.CONTAINS },
  role: { value: null, matchMode: FilterMatchMode.EQUALS }
})

// Pagination
const totalRecords = ref(0)
const lazyParams = ref({
  first: 0,
  rows: 10,
  page: 1,
  sortField: null,
  sortOrder: null,
  filters: filters.value
})

const loadUsers = async () => {
  loading.value = true
  try {
    const response = await axios.get('/api/users', {
      params: {
        page: lazyParams.value.page,
        per_page: lazyParams.value.rows,
        sort_by: lazyParams.value.sortField,
        sort_order: lazyParams.value.sortOrder === 1 ? 'asc' : 'desc',
        ...formatFilters(lazyParams.value.filters)
      }
    })
    users.value = response.data.data
    totalRecords.value = response.data.total
  } catch (error) {
    console.error('Failed to load users', error)
  } finally {
    loading.value = false
  }
}

const onPage = (event) => {
  lazyParams.value = event
  lazyParams.value.page = event.page + 1
  loadUsers()
}

const onSort = (event) => {
  lazyParams.value = event
  loadUsers()
}

const onFilter = () => {
  lazyParams.value.filters = filters.value
  lazyParams.value.page = 1
  loadUsers()
}

const formatFilters = (filters) => {
  const formatted = {}
  Object.keys(filters).forEach(key => {
    if (filters[key].value !== null) {
      formatted[key] = filters[key].value
    }
  })
  return formatted
}

onMounted(() => {
  loadUsers()
})
</script>

<template>
  <div class="card">
    <DataTable
      v-model:selection="selectedUsers"
      v-model:filters="filters"
      :value="users"
      :loading="loading"
      :lazy="true"
      :paginator="true"
      :rows="10"
      :total-records="totalRecords"
      :row-hover="true"
      filter-display="row"
      data-key="id"
      @page="onPage($event)"
      @sort="onSort($event)"
      @filter="onFilter()"
    >
      <template #header>
        <div class="flex justify-content-between">
          <Button
            label="New User"
            icon="pi pi-plus"
            @click="createUser"
          />
          <span class="p-input-icon-left">
            <i class="pi pi-search" />
            <InputText
              v-model="filters['global'].value"
              placeholder="Global Search"
            />
          </span>
        </div>
      </template>

      <Column
        selection-mode="multiple"
        style="width: 3rem"
        :exportable="false"
      />

      <Column
        field="id"
        header="ID"
        sortable
        style="width: 5rem"
      />

      <Column
        field="name"
        header="Name"
        sortable
      >
        <template #filter="{ filterModel, filterCallback }">
          <InputText
            v-model="filterModel.value"
            type="text"
            class="p-column-filter"
            placeholder="Search by name"
            @input="filterCallback()"
          />
        </template>
      </Column>

      <Column
        field="email"
        header="Email"
        sortable
      >
        <template #filter="{ filterModel, filterCallback }">
          <InputText
            v-model="filterModel.value"
            type="text"
            class="p-column-filter"
            placeholder="Search by email"
            @input="filterCallback()"
          />
        </template>
      </Column>

      <Column
        field="role"
        header="Role"
        sortable
      >
        <template #body="{ data }">
          <span :class="`badge badge-${data.role}`">
            {{ data.role }}
          </span>
        </template>
      </Column>

      <Column header="Actions" :exportable="false">
        <template #body="{ data }">
          <Button
            icon="pi pi-pencil"
            severity="info"
            text
            rounded
            @click="editUser(data)"
          />
          <Button
            icon="pi pi-trash"
            severity="danger"
            text
            rounded
            @click="confirmDelete(data)"
          />
        </template>
      </Column>
    </DataTable>
  </div>
</template>
```

### Form with Validation

```vue
<script setup>
import { ref, reactive } from 'vue'
import { useToast } from 'primevue/usetoast'
import InputText from 'primevue/inputtext'
import Dropdown from 'primevue/dropdown'
import Calendar from 'primevue/calendar'
import Button from 'primevue/button'

const toast = useToast()
const loading = ref(false)

const form = reactive({
  name: '',
  email: '',
  role: null,
  birthdate: null
})

const errors = ref({})

const roles = ref([
  { label: 'Admin', value: 'admin' },
  { label: 'Editor', value: 'editor' },
  { label: 'Viewer', value: 'viewer' }
])

const validate = () => {
  errors.value = {}
  
  if (!form.name) {
    errors.value.name = 'Name is required'
  }
  
  if (!form.email) {
    errors.value.email = 'Email is required'
  } else if (!/\S+@\S+\.\S+/.test(form.email)) {
    errors.value.email = 'Email is invalid'
  }
  
  if (!form.role) {
    errors.value.role = 'Role is required'
  }
  
  return Object.keys(errors.value).length === 0
}

const submit = async () => {
  if (!validate()) {
    return
  }
  
  loading.value = true
  try {
    await axios.post('/api/users', form)
    toast.add({
      severity: 'success',
      summary: 'Success',
      detail: 'User created successfully',
      life: 3000
    })
    resetForm()
  } catch (error) {
    if (error.response?.data?.errors) {
      errors.value = error.response.data.errors
    }
    toast.add({
      severity: 'error',
      summary: 'Error',
      detail: 'Failed to create user',
      life: 3000
    })
  } finally {
    loading.value = false
  }
}

const resetForm = () => {
  form.name = ''
  form.email = ''
  form.role = null
  form.birthdate = null
  errors.value = {}
}
</script>

<template>
  <div class="card">
    <form @submit.prevent="submit">
      <div class="field">
        <label for="name">Name *</label>
        <InputText
          id="name"
          v-model="form.name"
          :class="{ 'p-invalid': errors.name }"
          class="w-full"
        />
        <small v-if="errors.name" class="p-error">{{ errors.name }}</small>
      </div>

      <div class="field">
        <label for="email">Email *</label>
        <InputText
          id="email"
          v-model="form.email"
          type="email"
          :class="{ 'p-invalid': errors.email }"
          class="w-full"
        />
        <small v-if="errors.email" class="p-error">{{ errors.email }}</small>
      </div>

      <div class="field">
        <label for="role">Role *</label>
        <Dropdown
          id="role"
          v-model="form.role"
          :options="roles"
          option-label="label"
          option-value="value"
          placeholder="Select a role"
          :class="{ 'p-invalid': errors.role }"
          class="w-full"
        />
        <small v-if="errors.role" class="p-error">{{ errors.role }}</small>
      </div>

      <div class="field">
        <label for="birthdate">Birth Date</label>
        <Calendar
          id="birthdate"
          v-model="form.birthdate"
          date-format="yy-mm-dd"
          class="w-full"
        />
      </div>

      <div class="field">
        <Button
          type="submit"
          label="Submit"
          :loading="loading"
          class="w-full"
        />
      </div>
    </form>
  </div>
</template>

<style scoped>
.field {
  margin-bottom: 1.5rem;
}

label {
  display: block;
  margin-bottom: 0.5rem;
  font-weight: 600;
}
</style>
```

### Dialog Pattern

```vue
<script setup>
import { ref } from 'vue'
import Dialog from 'primevue/dialog'
import Button from 'primevue/button'

const visible = ref(false)
const user = ref(null)

const openDialog = (userData) => {
  user.value = { ...userData }
  visible.value = true
}

const closeDialog = () => {
  visible.value = false
  user.value = null
}

const saveUser = async () => {
  try {
    await axios.put(`/api/users/${user.value.id}`, user.value)
    closeDialog()
    toast.add({
      severity: 'success',
      summary: 'Success',
      detail: 'User updated successfully',
      life: 3000
    })
  } catch (error) {
    toast.add({
      severity: 'error',
      summary: 'Error',
      detail: 'Failed to update user',
      life: 3000
    })
  }
}

defineExpose({ openDialog })
</script>

<template>
  <Dialog
    v-model:visible="visible"
    modal
    header="Edit User"
    :style="{ width: '50vw' }"
    :breakpoints="{ '960px': '75vw', '641px': '90vw' }"
  >
    <div v-if="user" class="field">
      <label for="name">Name</label>
      <InputText
        id="name"
        v-model="user.name"
        class="w-full"
      />
    </div>

    <template #footer>
      <Button
        label="Cancel"
        severity="secondary"
        @click="closeDialog"
      />
      <Button
        label="Save"
        @click="saveUser"
      />
    </template>
  </Dialog>
</template>
```

## State Management with Pinia

```javascript
// stores/userStore.js
import { defineStore } from 'pinia'
import { ref, computed } from 'vue'

export const useUserStore = defineStore('user', () => {
  // State
  const currentUser = ref(null)
  const users = ref([])
  const loading = ref(false)

  // Getters
  const isAuthenticated = computed(() => currentUser.value !== null)
  const isAdmin = computed(() => currentUser.value?.role === 'admin')

  // Actions
  const fetchCurrentUser = async () => {
    loading.value = true
    try {
      const response = await axios.get('/api/auth/me')
      currentUser.value = response.data.data
    } catch (error) {
      currentUser.value = null
    } finally {
      loading.value = false
    }
  }

  const fetchUsers = async () => {
    loading.value = true
    try {
      const response = await axios.get('/api/users')
      users.value = response.data.data
    } catch (error) {
      console.error('Failed to fetch users', error)
    } finally {
      loading.value = false
    }
  }

  const logout = async () => {
    try {
      await axios.post('/api/auth/logout')
      currentUser.value = null
    } catch (error) {
      console.error('Logout failed', error)
    }
  }

  return {
    // State
    currentUser,
    users,
    loading,
    // Getters
    isAuthenticated,
    isAdmin,
    // Actions
    fetchCurrentUser,
    fetchUsers,
    logout
  }
})

// Usage in component
import { useUserStore } from '@/stores/userStore'

const userStore = useUserStore()

onMounted(() => {
  userStore.fetchCurrentUser()
})
```

## API Integration Setup

```javascript
// plugins/axios.js
import axios from 'axios'
import router from '../router'

const instance = axios.create({
  baseURL: import.meta.env.VITE_API_URL || '/api',
  timeout: 10000,
  headers: {
    'Content-Type': 'application/json',
    'Accept': 'application/json'
  }
})

// Request interceptor (add auth token)
instance.interceptors.request.use(
  (config) => {
    const token = localStorage.getItem('auth_token')
    if (token) {
      config.headers.Authorization = `Bearer ${token}`
    }
    return config
  },
  (error) => Promise.reject(error)
)

// Response interceptor (handle errors globally)
instance.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401) {
      localStorage.removeItem('auth_token')
      router.push('/login')
    }
    
    if (error.response?.status === 403) {
      router.push('/forbidden')
    }
    
    return Promise.reject(error)
  }
)

export default instance
```

## Performance Optimization

### Lazy Loading Components

```javascript
// router/index.js
const routes = [
  {
    path: '/users',
    name: 'Users',
    component: () => import('@/views/Users.vue') // Lazy load
  },
  {
    path: '/dashboard',
    name: 'Dashboard',
    component: () => import('@/views/Dashboard.vue')
  }
]
```

### Virtual Scrolling for Large Lists

```vue
<script setup>
import VirtualScroller from 'primevue/virtualscroller'

const items = ref(Array.from({ length: 100000 }, (_, i) => ({
  id: i,
  name: `Item ${i}`
})))
</script>

<template>
  <VirtualScroller
    :items="items"
    :item-size="50"
    class="border-1 surface-border border-round"
    style="width: 100%; height: 400px"
  >
    <template #item="{ item }">
      <div class="flex align-items-center p-2">
        {{ item.name }}
      </div>
    </template>
  </VirtualScroller>
</template>
```

### Debounce Search Input

```javascript
import { ref, watch } from 'vue'
import { useDebounceFn } from '@vueuse/core'

const searchQuery = ref('')
const users = ref([])

const debouncedSearch = useDebounceFn(async (query) => {
  const response = await axios.get('/api/users', {
    params: { search: query }
  })
  users.value = response.data.data
}, 500)

watch(searchQuery, (newValue) => {
  debouncedSearch(newValue)
})
```

## Loading States & UX

### Skeleton Loading

```vue
<script setup>
import Skeleton from 'primevue/skeleton'

const loading = ref(true)
const users = ref([])

onMounted(async () => {
  await fetchUsers()
  loading.value = false
})
</script>

<template>
  <div v-if="loading">
    <Skeleton height="2rem" class="mb-2" />
    <Skeleton height="2rem" class="mb-2" />
    <Skeleton height="2rem" class="mb-2" />
  </div>
  <div v-else>
    <!-- Actual content -->
  </div>
</template>
```

### Toast Notifications

```javascript
// main.js
import ToastService from 'primevue/toastservice'
app.use(ToastService)

// Component
import { useToast } from 'primevue/usetoast'

const toast = useToast()

toast.add({
  severity: 'success', // success, info, warn, error
  summary: 'Success',
  detail: 'Operation completed successfully',
  life: 3000
})
```

## Permission-Based UI

```vue
<script setup>
import { computed } from 'vue'
import { useUserStore } from '@/stores/userStore'

const userStore = useUserStore()

const canCreate = computed(() => {
  return userStore.currentUser?.permissions?.includes('create_users')
})

const canDelete = computed(() => {
  return userStore.currentUser?.permissions?.includes('delete_users')
})
</script>

<template>
  <div>
    <Button
      v-if="canCreate"
      label="Create User"
      @click="createUser"
    />

    <DataTable :value="users">
      <Column header="Actions">
        <template #body="{ data }">
          <Button
            v-if="canDelete"
            icon="pi pi-trash"
            @click="deleteUser(data)"
          />
        </template>
      </Column>
    </DataTable>
  </div>
</template>
```

## Legacy Vue 2 Support (Maintenance Only)

### Options API Pattern

```vue
<script>
export default {
  name: 'UserList',
  
  data() {
    return {
      users: [],
      loading: false
    }
  },
  
  computed: {
    activeUsers() {
      return this.users.filter(user => user.status === 'active')
    }
  },
  
  methods: {
    async fetchUsers() {
      this.loading = true
      try {
        const response = await this.$axios.get('/api/users')
        this.users = response.data.data
      } catch (error) {
        console.error('Failed to fetch users', error)
      } finally {
        this.loading = false
      }
    }
  },
  
  mounted() {
    this.fetchUsers()
  }
}
</script>
```

## Quasar to PrimeVue Migration Notes

- `QBtn` → `Button` (similar props)
- `QInput` → `InputText` (different event names)
- `QSelect` → `Dropdown` (data structure differs)
- `QTable` → `DataTable` (complete rewrite)
- `QDialog` → `Dialog` (props differ)
- `$q.notify()` → `toast.add()`
- `$q.loading` → Manual loading state

## Best Practices

1. **Use Composition API** over Options API (Vue 3)
2. **Extract reusable logic** into composables
3. **Keep components small** (< 300 lines)
4. **Use TypeScript** for type safety (if project supports)
5. **Lazy load routes** for better performance
6. **Always handle loading states** (skeletons, spinners)
7. **Show user feedback** (toast, dialog confirmation)
8. **Validate forms** before submitting
9. **Handle errors gracefully** (show user-friendly messages)
10. **Use PrimeVue's built-in accessibility** features
