---
name: TanStack Table
description: |
  Build headless data tables with TanStack Table v8. Provides server-side pagination, filtering, sorting, and virtualization patterns for Cloudflare Workers + D1 databases.

  Use when building tables with large datasets, coordinating with TanStack Query, or troubleshooting state management issues, pagination coordination errors, or performance bottlenecks.
---

# TanStack Table

Headless data tables with server-side pagination, filtering, sorting, and virtualization for Cloudflare Workers + D1

---

## Quick Start

**Last Updated**: 2026-01-09
**Versions**: @tanstack/react-table@8.21.3, @tanstack/react-virtual@3.13.18

```bash
npm install @tanstack/react-table@latest
npm install @tanstack/react-virtual@latest  # For virtualization
```

**Basic Setup** (CRITICAL: memoize data/columns to prevent infinite re-renders):
```typescript
import { useReactTable, getCoreRowModel, ColumnDef } from '@tanstack/react-table'
import { useMemo } from 'react'

const columns: ColumnDef<User>[] = [
  { accessorKey: 'name', header: 'Name' },
  { accessorKey: 'email', header: 'Email' },
]

function UsersTable() {
  const data = useMemo(() => [...users], []) // Stable reference
  const table = useReactTable({ data, columns, getCoreRowModel: getCoreRowModel() })

  return (
    <table>
      <thead>
        {table.getHeaderGroups().map(group => (
          <tr key={group.id}>
            {group.headers.map(h => <th key={h.id}>{h.column.columnDef.header}</th>)}
          </tr>
        ))}
      </thead>
      <tbody>
        {table.getRowModel().rows.map(row => (
          <tr key={row.id}>
            {row.getVisibleCells().map(cell => <td key={cell.id}>{cell.renderValue()}</td>)}
          </tr>
        ))}
      </tbody>
    </table>
  )
}
```

---

## Server-Side Patterns

**Cloudflare D1 API** (pagination + filtering + sorting):
```typescript
// Workers API: functions/api/users.ts
export async function onRequestGet({ request, env }) {
  const url = new URL(request.url)
  const page = Number(url.searchParams.get('page')) || 0
  const pageSize = 20
  const search = url.searchParams.get('search') || ''
  const sortBy = url.searchParams.get('sortBy') || 'created_at'
  const sortOrder = url.searchParams.get('sortOrder') || 'DESC'

  const { results } = await env.DB.prepare(`
    SELECT * FROM users
    WHERE name LIKE ? OR email LIKE ?
    ORDER BY ${sortBy} ${sortOrder}
    LIMIT ? OFFSET ?
  `).bind(`%${search}%`, `%${search}%`, pageSize, page * pageSize).all()

  const { total } = await env.DB.prepare('SELECT COUNT(*) as total FROM users').first()

  return Response.json({
    data: results,
    pagination: { page, pageSize, total, pageCount: Math.ceil(total / pageSize) },
  })
}
```

**Client-Side** (TanStack Query + Table):
```typescript
const [pagination, setPagination] = useState({ pageIndex: 0, pageSize: 20 })
const [columnFilters, setColumnFilters] = useState([])
const [sorting, setSorting] = useState([])

// CRITICAL: Include ALL state in query key
const { data, isLoading } = useQuery({
  queryKey: ['users', pagination, columnFilters, sorting],
  queryFn: async () => {
    const params = new URLSearchParams({
      page: pagination.pageIndex,
      search: columnFilters.find(f => f.id === 'search')?.value || '',
      sortBy: sorting[0]?.id || 'created_at',
      sortOrder: sorting[0]?.desc ? 'DESC' : 'ASC',
    })
    return fetch(`/api/users?${params}`).then(r => r.json())
  },
})

const table = useReactTable({
  data: data?.data ?? [],
  columns,
  getCoreRowModel: getCoreRowModel(),
  // CRITICAL: manual* flags tell table server handles these
  manualPagination: true,
  manualFiltering: true,
  manualSorting: true,
  pageCount: data?.pagination.pageCount ?? 0,
  state: { pagination, columnFilters, sorting },
  onPaginationChange: setPagination,
  onColumnFiltersChange: setColumnFilters,
  onSortingChange: setSorting,
})
```

---

## Virtualization (1000+ Rows)

Render only visible rows for performance:
```typescript
import { useVirtualizer } from '@tanstack/react-virtual'

function VirtualizedTable() {
  const containerRef = useRef<HTMLDivElement>(null)
  const table = useReactTable({ data: largeDataset, columns, getCoreRowModel: getCoreRowModel() })
  const { rows } = table.getRowModel()

  const rowVirtualizer = useVirtualizer({
    count: rows.length,
    getScrollElement: () => containerRef.current,
    estimateSize: () => 50, // Row height px
    overscan: 10,
  })

  return (
    <div ref={containerRef} style={{ height: '600px', overflow: 'auto' }}>
      <table style={{ height: `${rowVirtualizer.getTotalSize()}px` }}>
        <tbody>
          {rowVirtualizer.getVirtualItems().map(virtualRow => {
            const row = rows[virtualRow.index]
            return (
              <tr key={row.id} style={{ position: 'absolute', transform: `translateY(${virtualRow.start}px)` }}>
                {row.getVisibleCells().map(cell => <td key={cell.id}>{cell.renderValue()}</td>)}
              </tr>
            )
          })}
        </tbody>
      </table>
    </div>
  )
}
```

---

## Column/Row Pinning

Pin columns or rows to keep them visible during horizontal/vertical scroll:

```typescript
import { useReactTable, getCoreRowModel } from '@tanstack/react-table'

const table = useReactTable({
  data,
  columns,
  getCoreRowModel: getCoreRowModel(),
  // Enable pinning
  enableColumnPinning: true,
  enableRowPinning: true,
  // Initial pinning state
  initialState: {
    columnPinning: {
      left: ['select', 'name'],  // Pin to left
      right: ['actions'],        // Pin to right
    },
  },
})

// Render with pinned columns
function PinnedTable() {
  return (
    <div className="flex">
      {/* Left pinned columns */}
      <div className="sticky left-0 bg-background z-10">
        {table.getLeftHeaderGroups().map(/* render left headers */)}
        {table.getRowModel().rows.map(row => (
          <tr>{row.getLeftVisibleCells().map(/* render cells */)}</tr>
        ))}
      </div>

      {/* Center scrollable columns */}
      <div className="overflow-x-auto">
        {table.getCenterHeaderGroups().map(/* render center headers */)}
        {table.getRowModel().rows.map(row => (
          <tr>{row.getCenterVisibleCells().map(/* render cells */)}</tr>
        ))}
      </div>

      {/* Right pinned columns */}
      <div className="sticky right-0 bg-background z-10">
        {table.getRightHeaderGroups().map(/* render right headers */)}
        {table.getRowModel().rows.map(row => (
          <tr>{row.getRightVisibleCells().map(/* render cells */)}</tr>
        ))}
      </div>
    </div>
  )
}

// Toggle pinning programmatically
column.pin('left')   // Pin column to left
column.pin('right')  // Pin column to right
column.pin(false)    // Unpin column
row.pin('top')       // Pin row to top
row.pin('bottom')    // Pin row to bottom
```

---

## Row Expanding (Nested Data)

Show/hide child rows or additional details:

```typescript
import { useReactTable, getCoreRowModel, getExpandedRowModel } from '@tanstack/react-table'

// Data with nested children
const data = [
  {
    id: 1,
    name: 'Parent Row',
    subRows: [
      { id: 2, name: 'Child Row 1' },
      { id: 3, name: 'Child Row 2' },
    ],
  },
]

const table = useReactTable({
  data,
  columns,
  getCoreRowModel: getCoreRowModel(),
  getExpandedRowModel: getExpandedRowModel(),  // Required for expanding
  getSubRows: row => row.subRows,               // Tell table where children are
})

// Render with expand button
function ExpandableTable() {
  return (
    <tbody>
      {table.getRowModel().rows.map(row => (
        <>
          <tr key={row.id}>
            <td>
              {row.getCanExpand() && (
                <button onClick={row.getToggleExpandedHandler()}>
                  {row.getIsExpanded() ? '▼' : '▶'}
                </button>
              )}
            </td>
            {row.getVisibleCells().map(cell => (
              <td key={cell.id} style={{ paddingLeft: `${row.depth * 20}px` }}>
                {cell.renderValue()}
              </td>
            ))}
          </tr>
        </>
      ))}
    </tbody>
  )
}

// Control expansion programmatically
table.toggleAllRowsExpanded()     // Expand/collapse all
row.toggleExpanded()              // Toggle single row
table.getIsAllRowsExpanded()      // Check if all expanded
```

**Detail Rows** (custom content, not nested data):

```typescript
function DetailRow({ row }) {
  if (!row.getIsExpanded()) return null

  return (
    <tr>
      <td colSpan={columns.length}>
        <div className="p-4 bg-muted">
          Custom detail content for row {row.id}
        </div>
      </td>
    </tr>
  )
}
```

---

## Row Grouping

Group rows by column values:

```typescript
import { useReactTable, getCoreRowModel, getGroupedRowModel } from '@tanstack/react-table'

const table = useReactTable({
  data,
  columns,
  getCoreRowModel: getCoreRowModel(),
  getGroupedRowModel: getGroupedRowModel(),    // Required for grouping
  getExpandedRowModel: getExpandedRowModel(),  // Groups are expandable
  initialState: {
    grouping: ['status'],  // Group by 'status' column
  },
})

// Column with aggregation
const columns = [
  {
    accessorKey: 'status',
    header: 'Status',
  },
  {
    accessorKey: 'amount',
    header: 'Amount',
    aggregationFn: 'sum',                      // Sum grouped values
    aggregatedCell: ({ getValue }) => `Total: ${getValue()}`,
  },
]

// Render grouped table
function GroupedTable() {
  return (
    <tbody>
      {table.getRowModel().rows.map(row => (
        <tr key={row.id}>
          {row.getVisibleCells().map(cell => (
            <td key={cell.id}>
              {cell.getIsGrouped() ? (
                // Grouped cell - show group header with expand toggle
                <button onClick={row.getToggleExpandedHandler()}>
                  {row.getIsExpanded() ? '▼' : '▶'} {cell.renderValue()} ({row.subRows.length})
                </button>
              ) : cell.getIsAggregated() ? (
                // Aggregated cell - show aggregation result
                cell.renderValue()
              ) : cell.getIsPlaceholder() ? null : (
                // Regular cell
                cell.renderValue()
              )}
            </td>
          ))}
        </tr>
      ))}
    </tbody>
  )
}

// Built-in aggregation functions
// 'sum', 'min', 'max', 'extent', 'mean', 'median', 'unique', 'uniqueCount', 'count'
```

---

## Known Issues & Solutions

**Issue #1: Infinite Re-Renders**
- **Error**: Table re-renders infinitely, browser freezes
- **Cause**: `data` or `columns` references change on every render
- **Fix**: Use `useMemo(() => [...], [])` or define data/columns outside component

**Issue #2: Query + Table State Mismatch**
- **Error**: Query refetches but pagination state not synced, stale data
- **Cause**: Query key missing table state (pagination, filters, sorting)
- **Fix**: Include ALL state in query key: `queryKey: ['users', pagination, columnFilters, sorting]`

**Issue #3: Server-Side Features Not Working**
- **Error**: Pagination/filtering/sorting doesn't trigger API calls
- **Cause**: Missing `manual*` flags
- **Fix**: Set `manualPagination: true`, `manualFiltering: true`, `manualSorting: true` + provide `pageCount`

**Issue #4: TypeScript "Cannot Find Module"**
- **Error**: Import errors for `createColumnHelper`
- **Fix**: Import from `@tanstack/react-table` (NOT `@tanstack/table-core`)

**Issue #5: Sorting Not Working Server-Side**
- **Error**: Clicking sort headers doesn't update data
- **Cause**: Sorting state not in query key/API params
- **Fix**: Include `sorting` in query key, add sort params to API call, set `manualSorting: true` + `onSortingChange`

**Issue #6: Poor Performance (1000+ Rows)**
- **Error**: Table slow/laggy with large datasets
- **Fix**: Use TanStack Virtual for client-side OR implement server-side pagination

---

**Related Skills**: tanstack-query (data fetching), cloudflare-d1 (database backend), tailwind-v4-shadcn (UI styling)
