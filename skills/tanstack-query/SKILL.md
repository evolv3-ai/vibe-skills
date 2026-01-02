---
name: tanstack-query
description: |
  Manage server state in React with TanStack Query v5. Set up queries with useQuery, mutations with useMutation, configure QueryClient caching strategies, implement optimistic updates, and handle infinite scroll with useInfiniteQuery.

  Use when: setting up data fetching in React projects, migrating from v4 to v5, or fixing object syntax required errors, query callbacks removed issues, cacheTime renamed to gcTime, isPending vs isLoading confusion, keepPreviousData removed problems.
---

# TanStack Query (React Query) v5

**Last Updated**: 2025-11-28
**Versions**: @tanstack/react-query@5.90.16, @tanstack/react-query-devtools@5.90.2
**Requires**: React 18.0+ (useSyncExternalStore), TypeScript 4.7+ (recommended)

---

## Quick Setup

```bash
npm install @tanstack/react-query@latest
npm install -D @tanstack/react-query-devtools@latest
```

### Step 2: Provider + Config

```tsx
// src/main.tsx
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { ReactQueryDevtools } from '@tanstack/react-query-devtools'

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 1000 * 60 * 5, // 5 min
      gcTime: 1000 * 60 * 60, // 1 hour (v5: renamed from cacheTime)
      refetchOnWindowFocus: false,
    },
  },
})

<QueryClientProvider client={queryClient}>
  <App />
  <ReactQueryDevtools initialIsOpen={false} />
</QueryClientProvider>
```

### Step 3: Query + Mutation Hooks

```tsx
// src/hooks/useTodos.ts
import { useQuery, useMutation, useQueryClient, queryOptions } from '@tanstack/react-query'

// Query options factory (v5 pattern)
export const todosQueryOptions = queryOptions({
  queryKey: ['todos'],
  queryFn: async () => {
    const res = await fetch('/api/todos')
    if (!res.ok) throw new Error('Failed to fetch')
    return res.json()
  },
})

export function useTodos() {
  return useQuery(todosQueryOptions)
}

export function useAddTodo() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: async (newTodo) => {
      const res = await fetch('/api/todos', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(newTodo),
      })
      if (!res.ok) throw new Error('Failed to add')
      return res.json()
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['todos'] })
    },
  })
}

// Usage:
function TodoList() {
  const { data, isPending, isError, error } = useTodos()
  const { mutate } = useAddTodo()

  if (isPending) return <div>Loading...</div>
  if (isError) return <div>Error: {error.message}</div>
  return <ul>{data.map(todo => <li key={todo.id}>{todo.title}</li>)}</ul>
}
```

---

## Critical Rules

### Always Do

✅ **Use object syntax for all hooks**
```tsx
// v5 ONLY supports this:
useQuery({ queryKey, queryFn, ...options })
useMutation({ mutationFn, ...options })
```

✅ **Use array query keys**
```tsx
queryKey: ['todos']              // List
queryKey: ['todos', id]          // Detail
queryKey: ['todos', { filter }]  // Filtered
```

✅ **Configure staleTime appropriately**
```tsx
staleTime: 1000 * 60 * 5 // 5 min - prevents excessive refetches
```

✅ **Use isPending for initial loading state**
```tsx
if (isPending) return <Loading />
// isPending = no data yet AND fetching
```

✅ **Throw errors in queryFn**
```tsx
if (!response.ok) throw new Error('Failed')
```

✅ **Invalidate queries after mutations**
```tsx
onSuccess: () => {
  queryClient.invalidateQueries({ queryKey: ['todos'] })
}
```

✅ **Use queryOptions factory for reusable patterns**
```tsx
const opts = queryOptions({ queryKey, queryFn })
useQuery(opts)
useSuspenseQuery(opts)
prefetchQuery(opts)
```

✅ **Use gcTime (not cacheTime)**
```tsx
gcTime: 1000 * 60 * 60 // 1 hour
```

### Never Do

❌ **Never use v4 array/function syntax**
```tsx
// v4 (removed in v5):
useQuery(['todos'], fetchTodos, options) // ❌

// v5 (correct):
useQuery({ queryKey: ['todos'], queryFn: fetchTodos }) // ✅
```

❌ **Never use query callbacks (onSuccess, onError, onSettled in queries)**
```tsx
// v5 removed these from queries:
useQuery({
  queryKey: ['todos'],
  queryFn: fetchTodos,
  onSuccess: (data) => {}, // ❌ Removed in v5
})

// Use useEffect instead:
const { data } = useQuery({ queryKey: ['todos'], queryFn: fetchTodos })
useEffect(() => {
  if (data) {
    // Do something
  }
}, [data])

// Or use mutation callbacks (still supported):
useMutation({
  mutationFn: addTodo,
  onSuccess: () => {}, // ✅ Still works for mutations
})
```

❌ **Never use deprecated options**
```tsx
// Deprecated in v5:
cacheTime: 1000 // ❌ Use gcTime instead
isLoading: true // ❌ Meaning changed, use isPending
keepPreviousData: true // ❌ Use placeholderData instead
onSuccess: () => {} // ❌ Removed from queries
useErrorBoundary: true // ❌ Use throwOnError instead
```

❌ **Never assume isLoading means "no data yet"**
```tsx
// v5 changed this:
isLoading = isPending && isFetching // ❌ Now means "pending AND fetching"
isPending = no data yet // ✅ Use this for initial load
```

❌ **Never forget initialPageParam for infinite queries**
```tsx
// v5 requires this:
useInfiniteQuery({
  queryKey: ['projects'],
  queryFn: ({ pageParam }) => fetchProjects(pageParam),
  initialPageParam: 0, // ✅ Required in v5
  getNextPageParam: (lastPage) => lastPage.nextCursor,
})
```

❌ **Never use enabled with useSuspenseQuery**
```tsx
// Not allowed:
useSuspenseQuery({
  queryKey: ['todo', id],
  queryFn: () => fetchTodo(id),
  enabled: !!id, // ❌ Not available with suspense
})

// Use conditional rendering instead:
{id && <TodoComponent id={id} />}
```

---

## Known Issues Prevention

This skill prevents **8 documented issues** from v5 migration and common mistakes:

### Issue #1: Object Syntax Required
**Error**: `useQuery is not a function` or type errors
**Source**: [v5 Migration Guide](https://tanstack.com/query/latest/docs/framework/react/guides/migrating-to-v5#removed-overloads-in-favor-of-object-syntax)
**Why It Happens**: v5 removed all function overloads, only object syntax works
**Prevention**: Always use `useQuery({ queryKey, queryFn, ...options })`

**Before (v4):**
```tsx
useQuery(['todos'], fetchTodos, { staleTime: 5000 })
```

**After (v5):**
```tsx
useQuery({
  queryKey: ['todos'],
  queryFn: fetchTodos,
  staleTime: 5000
})
```

### Issue #2: Query Callbacks Removed
**Error**: Callbacks don't run, TypeScript errors
**Source**: [v5 Breaking Changes](https://tanstack.com/query/latest/docs/framework/react/guides/migrating-to-v5#callbacks-on-usequery-and-queryobserver-have-been-removed)
**Why It Happens**: onSuccess, onError, onSettled removed from queries (still work in mutations)
**Prevention**: Use `useEffect` for side effects, or move logic to mutation callbacks

**Before (v4):**
```tsx
useQuery({
  queryKey: ['todos'],
  queryFn: fetchTodos,
  onSuccess: (data) => {
    console.log('Todos loaded:', data)
  },
})
```

**After (v5):**
```tsx
const { data } = useQuery({ queryKey: ['todos'], queryFn: fetchTodos })
useEffect(() => {
  if (data) {
    console.log('Todos loaded:', data)
  }
}, [data])
```

### Issue #3: Status Loading → Pending
**Error**: UI shows wrong loading state
**Source**: [v5 Migration: isLoading renamed](https://tanstack.com/query/latest/docs/framework/react/guides/migrating-to-v5#isloading-and-isfetching-flags)
**Why It Happens**: `status: 'loading'` renamed to `status: 'pending'`, `isLoading` meaning changed
**Prevention**: Use `isPending` for initial load, `isLoading` for "pending AND fetching"

**Before (v4):**
```tsx
const { data, isLoading } = useQuery(...)
if (isLoading) return <div>Loading...</div>
```

**After (v5):**
```tsx
const { data, isPending, isLoading } = useQuery(...)
if (isPending) return <div>Loading...</div>
// isLoading = isPending && isFetching (fetching for first time)
```

### Issue #4: cacheTime → gcTime
**Error**: `cacheTime is not a valid option`
**Source**: [v5 Migration: gcTime](https://tanstack.com/query/latest/docs/framework/react/guides/migrating-to-v5#cachetime-has-been-replaced-by-gctime)
**Why It Happens**: Renamed to better reflect "garbage collection time"
**Prevention**: Use `gcTime` instead of `cacheTime`

**Before (v4):**
```tsx
useQuery({
  queryKey: ['todos'],
  queryFn: fetchTodos,
  cacheTime: 1000 * 60 * 60,
})
```

**After (v5):**
```tsx
useQuery({
  queryKey: ['todos'],
  queryFn: fetchTodos,
  gcTime: 1000 * 60 * 60,
})
```

### Issue #5: useSuspenseQuery + enabled
**Error**: Type error, enabled option not available
**Source**: [GitHub Discussion #6206](https://github.com/TanStack/query/discussions/6206)
**Why It Happens**: Suspense guarantees data is available, can't conditionally disable
**Prevention**: Use conditional rendering instead of `enabled` option

**Before (v4/incorrect):**
```tsx
useSuspenseQuery({
  queryKey: ['todo', id],
  queryFn: () => fetchTodo(id),
  enabled: !!id, // ❌ Not allowed
})
```

**After (v5/correct):**
```tsx
// Conditional rendering:
{id ? (
  <TodoComponent id={id} />
) : (
  <div>No ID selected</div>
)}

// Inside TodoComponent:
function TodoComponent({ id }: { id: number }) {
  const { data } = useSuspenseQuery({
    queryKey: ['todo', id],
    queryFn: () => fetchTodo(id),
    // No enabled option needed
  })
  return <div>{data.title}</div>
}
```

### Issue #6: initialPageParam Required
**Error**: `initialPageParam is required` type error
**Source**: [v5 Migration: Infinite Queries](https://tanstack.com/query/latest/docs/framework/react/guides/migrating-to-v5#new-required-initialPageParam-option)
**Why It Happens**: v4 passed `undefined` as first pageParam, v5 requires explicit value
**Prevention**: Always specify `initialPageParam` for infinite queries

**Before (v4):**
```tsx
useInfiniteQuery({
  queryKey: ['projects'],
  queryFn: ({ pageParam = 0 }) => fetchProjects(pageParam),
  getNextPageParam: (lastPage) => lastPage.nextCursor,
})
```

**After (v5):**
```tsx
useInfiniteQuery({
  queryKey: ['projects'],
  queryFn: ({ pageParam }) => fetchProjects(pageParam),
  initialPageParam: 0, // ✅ Required
  getNextPageParam: (lastPage) => lastPage.nextCursor,
})
```

### Issue #7: keepPreviousData Removed
**Error**: `keepPreviousData is not a valid option`
**Source**: [v5 Migration: placeholderData](https://tanstack.com/query/latest/docs/framework/react/guides/migrating-to-v5#removed-keeppreviousdata-in-favor-of-placeholderdata-identity-function)
**Why It Happens**: Replaced with more flexible `placeholderData` function
**Prevention**: Use `placeholderData: keepPreviousData` helper

**Before (v4):**
```tsx
useQuery({
  queryKey: ['todos', page],
  queryFn: () => fetchTodos(page),
  keepPreviousData: true,
})
```

**After (v5):**
```tsx
import { keepPreviousData } from '@tanstack/react-query'

useQuery({
  queryKey: ['todos', page],
  queryFn: () => fetchTodos(page),
  placeholderData: keepPreviousData,
})
```

### Issue #8: TypeScript Error Type Default
**Error**: Type errors with error handling
**Source**: [v5 Migration: Error Types](https://tanstack.com/query/latest/docs/framework/react/guides/migrating-to-v5#typeerror-is-now-the-default-error)
**Why It Happens**: v4 used `unknown`, v5 defaults to `Error` type
**Prevention**: If throwing non-Error types, specify error type explicitly

**Before (v4 - error was unknown):**
```tsx
const { error } = useQuery({
  queryKey: ['data'],
  queryFn: async () => {
    if (Math.random() > 0.5) throw 'custom error string'
    return data
  },
})
// error: unknown
```

**After (v5 - specify custom error type):**
```tsx
const { error } = useQuery<DataType, string>({
  queryKey: ['data'],
  queryFn: async () => {
    if (Math.random() > 0.5) throw 'custom error string'
    return data
  },
})
// error: string | null

// Or better: always throw Error objects
const { error } = useQuery({
  queryKey: ['data'],
  queryFn: async () => {
    if (Math.random() > 0.5) throw new Error('custom error')
    return data
  },
})
// error: Error | null (default)
```

---

## Key Patterns

**Dependent Queries** (Query B waits for Query A):
```tsx
const { data: posts } = useQuery({
  queryKey: ['users', userId, 'posts'],
  queryFn: () => fetchUserPosts(userId),
  enabled: !!user, // Wait for user
})
```

**Parallel Queries** (fetch multiple at once):
```tsx
const results = useQueries({
  queries: ids.map(id => ({ queryKey: ['todos', id], queryFn: () => fetchTodo(id) })),
})
```

**Prefetching** (preload on hover):
```tsx
queryClient.prefetchQuery({ queryKey: ['todo', id], queryFn: () => fetchTodo(id) })
```

**Infinite Scroll** (useInfiniteQuery):
```tsx
useInfiniteQuery({
  queryKey: ['todos', 'infinite'],
  queryFn: ({ pageParam }) => fetchTodosPage(pageParam),
  initialPageParam: 0, // Required in v5
  getNextPageParam: (lastPage) => lastPage.nextCursor,
})
```

**Query Cancellation** (auto-cancel on queryKey change):
```tsx
queryFn: async ({ signal }) => {
  const res = await fetch(`/api/todos?q=${search}`, { signal })
  return res.json()
}
```

**Data Transformation** (select):
```tsx
select: (data) => data.filter(todo => todo.completed)
```

**Avoid Request Waterfalls**: Fetch in parallel when possible (don't chain queries unless truly dependent)

---

**Official Docs**: https://tanstack.com/query/latest | **v5 Migration**: https://tanstack.com/query/latest/docs/framework/react/guides/migrating-to-v5 | **GitHub**: https://github.com/TanStack/query | **Context7**: `/websites/tanstack_query`
