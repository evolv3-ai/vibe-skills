# Edge Runtime Compatibility Guide

**Last Updated**: 2025-10-26
**Auth.js Version**: v5 (next-auth 4.24+)

This guide explains Auth.js compatibility with edge runtimes like Cloudflare Workers, Vercel Edge Functions, and Next.js middleware.

---

## What is Edge Runtime?

Edge runtimes execute code closer to users at edge locations worldwide. They have limitations compared to Node.js:

- **No Node.js APIs**: crypto, fs, path, etc. not available
- **Limited compute time**: Usually <30s per request
- **No dynamic code evaluation**: eval(), new Function() not allowed
- **Smaller bundle size limits**: V8 isolates have size constraints

**Edge Platforms:**
- Cloudflare Workers
- Vercel Edge Functions
- Next.js Middleware
- Deno Deploy
- Netlify Edge Functions

---

## Database Adapter Compatibility

### Edge-Compatible Adapters ✅

| Adapter | Edge Compatible | Notes |
|---------|----------------|-------|
| **D1 Adapter** | ✅ Yes | Cloudflare D1 (SQLite) |
| **Upstash Redis** | ✅ Yes | HTTP-based Redis |
| **Neon** | ✅ Yes | Serverless Postgres via HTTP |
| **PlanetScale** | ✅ Yes | MySQL via HTTP |
| **Supabase** | ✅ Yes | With edge client |
| **Firebase** | ⚠️ Partial | Client SDK only |

### NOT Edge-Compatible ❌

| Adapter | Edge Compatible | Reason |
|---------|----------------|--------|
| **Prisma** | ❌ No | Uses Node.js crypto, binary engines |
| **TypeORM** | ❌ No | Requires Node.js runtime |
| **MongoDB** | ❌ No | Native driver requires Node.js |
| **PostgreSQL** | ❌ No | pg driver requires Node.js |
| **MySQL** | ❌ No | mysql2 requires Node.js |

---

## Session Strategy Compatibility

### JWT Sessions ✅

**Edge Compatible**: YES

```typescript
export const { handlers, auth } = NextAuth({
  session: { strategy: "jwt" }, // ✅ Works in edge
  providers: [GitHub],
})
```

**Why it works:**
- No database queries needed
- All data in encrypted JWT token
- Uses Web Crypto API (available in edge)

**Use cases:**
- Next.js middleware
- Cloudflare Workers
- Vercel Edge Functions
- Any edge runtime

### Database Sessions ⚠️

**Edge Compatible**: DEPENDS ON ADAPTER

```typescript
export const { handlers, auth } = NextAuth({
  adapter: D1Adapter(env.DB), // ✅ Edge-compatible
  session: { strategy: "database" }, // ✅ Works with D1
})
```

```typescript
export const { handlers, auth } = NextAuth({
  adapter: PrismaAdapter(prisma), // ❌ NOT edge-compatible
  session: { strategy: "database" }, // ❌ Fails in edge
})
```

**Why it depends:**
- Requires adapter that works in edge runtime
- D1, Upstash Redis, Neon: Edge-compatible
- Prisma, TypeORM, MongoDB: NOT edge-compatible

---

## Recommended Patterns

### Pattern 1: JWT Sessions (Simplest)

**Use when**: Don't need database sessions

```typescript
// auth.ts
import NextAuth from "next-auth"
import GitHub from "next-auth/providers/github"

export const { handlers, auth } = NextAuth({
  // No adapter = JWT sessions by default
  session: { strategy: "jwt" }, // Explicit JWT
  providers: [GitHub],
})

// middleware.ts
export { auth as middleware } from "@/auth"
```

**Pros:**
- ✅ Works everywhere (Node.js + edge)
- ✅ No database queries
- ✅ Fastest performance
- ✅ Simplest setup

**Cons:**
- ❌ Can't invalidate sessions server-side
- ❌ Token size limits (~4KB)
- ❌ All data in client-accessible token

---

### Pattern 2: Split Configuration (Recommended)

**Use when**: Need database adapter but also use middleware

```typescript
// auth.config.ts (edge-compatible, no adapter)
import type { NextAuthConfig } from "next-auth"
import GitHub from "next-auth/providers/github"

export default {
  providers: [GitHub],
} satisfies NextAuthConfig

// auth.ts (full config with database)
import NextAuth from "next-auth"
import { PrismaAdapter } from "@auth/prisma-adapter"
import authConfig from "./auth.config"

export const { handlers, auth } = NextAuth({
  adapter: PrismaAdapter(prisma), // Not edge-compatible
  session: { strategy: "jwt" }, // ✅ FORCE JWT for middleware
  ...authConfig,
})

// middleware.ts (uses edge-compatible config)
import NextAuth from "next-auth"
import authConfig from "./auth.config"

const { auth } = NextAuth(authConfig)
export { auth as middleware }
```

**Pros:**
- ✅ Works in both Node.js and edge
- ✅ Can use any database adapter
- ✅ Middleware still works (JWT sessions)
- ✅ Full Auth.js features in server-side code

**Cons:**
- ⚠️ More complex setup
- ⚠️ JWT sessions only (can't use database sessions)

**Why this works:**
- Middleware uses `auth.config.ts` (no adapter, no database)
- Server-side uses `auth.ts` (full adapter, database)
- JWT sessions work in both contexts

---

### Pattern 3: Edge-Compatible Adapter

**Use when**: Using edge platform with edge-compatible database

```typescript
// Cloudflare Workers + D1
import { Hono } from 'hono'
import { Auth } from '@auth/core'
import { D1Adapter } from '@auth/d1-adapter'

app.all('/api/auth/*', async (c) => {
  return await Auth(c.req.raw, {
    adapter: D1Adapter(c.env.DB), // ✅ Edge-compatible
    session: { strategy: "database" }, // ✅ Can use database sessions
    providers: [GitHub],
  })
})
```

**Pros:**
- ✅ Full edge compatibility
- ✅ Can use database sessions
- ✅ Server-side session invalidation
- ✅ Audit trail in database

**Cons:**
- ⚠️ Limited to edge-compatible databases
- ⚠️ Platform-specific (Cloudflare, Upstash, etc.)

---

## Cloudflare Workers Specific

### D1 Adapter Setup

```typescript
// wrangler.jsonc
{
  "d1_databases": [
    {
      "binding": "DB",
      "database_name": "auth_db",
      "database_id": "your-database-id"
    }
  ]
}
```

```typescript
// worker.ts
import { Hono } from 'hono'
import { Auth } from '@auth/core'
import { D1Adapter } from '@auth/d1-adapter'
import GitHub from '@auth/core/providers/github'

type Bindings = {
  DB: D1Database
  AUTH_SECRET: string
}

const app = new Hono<{ Bindings: Bindings }>()

app.all('/api/auth/*', async (c) => {
  return await Auth(c.req.raw, {
    adapter: D1Adapter(c.env.DB),
    providers: [GitHub({
      clientId: c.env.AUTH_GITHUB_ID,
      clientSecret: c.env.AUTH_GITHUB_SECRET,
    })],
    secret: c.env.AUTH_SECRET,
    trustHost: true, // Required for Workers
  })
})

export default app
```

### Critical Requirements for Workers

1. **trustHost: true** - Required for Cloudflare Workers
2. **Access bindings from request context** - Not globally
3. **Use environment variables for secrets** - Not in code
4. **Run migrations before deploying** - D1 tables must exist

### Common Cloudflare Issues

**Issue**: `env.DB is undefined`
```typescript
// WRONG - binding not available outside request
const adapter = D1Adapter(env.DB)

// CORRECT - access from request context
app.all('/api/auth/*', async (c) => {
  const adapter = D1Adapter(c.env.DB)
})
```

**Issue**: `Database not found`
```bash
# Create database
npx wrangler d1 create auth_db

# Run migrations
npx wrangler d1 execute auth_db --file=./schema.sql
```

---

## Next.js Middleware

### Compatible Approaches

**Option 1: JWT Sessions Only**
```typescript
// auth.ts
export const { handlers, auth } = NextAuth({
  session: { strategy: "jwt" }, // ✅ Edge-compatible
  providers: [GitHub],
})

// middleware.ts
export { auth as middleware } from "@/auth"
```

**Option 2: Split Config**
```typescript
// auth.config.ts (no adapter)
export default {
  providers: [GitHub],
} satisfies NextAuthConfig

// middleware.ts
import authConfig from "./auth.config"
const { auth } = NextAuth(authConfig)
export { auth as middleware }
```

### Middleware Limitations

**What works in middleware:**
- ✅ Check if user is authenticated
- ✅ Access session.user data (if in JWT)
- ✅ Redirect based on auth state
- ✅ Role-based access control (if role in JWT)

**What doesn't work:**
- ❌ Database queries (unless edge-compatible adapter)
- ❌ Session invalidation (with JWT sessions)
- ❌ Node.js APIs (fs, crypto, etc.)
- ❌ Large computations (timeout limits)

---

## Vercel Edge Functions

**Same as Next.js middleware**

```typescript
// app/api/auth/[...nextauth]/route.ts (edge runtime)
export const runtime = 'edge'

import { handlers } from "@/auth"
export const { GET, POST } = handlers
```

**Requirements:**
- JWT sessions OR edge-compatible adapter
- No Node.js dependencies
- Keep bundle size small

---

## Compatibility Checklist

Before deploying to edge runtime:

- [ ] Using JWT sessions OR edge-compatible adapter
- [ ] No Node.js APIs in auth config
- [ ] Split config if using non-edge adapter
- [ ] Tested in edge runtime locally
- [ ] Environment variables configured
- [ ] Database migrations run (if using adapter)
- [ ] OAuth callback URLs updated
- [ ] Bundle size within limits

---

## Testing Edge Compatibility

### Local Testing (Cloudflare Workers)
```bash
# Test locally with Wrangler
npx wrangler dev

# Check for edge runtime errors
# Look for: "Module not compatible with edge runtime"
```

### Local Testing (Next.js Middleware)
```bash
# Next.js middleware runs in edge by default
npm run dev

# Access protected route
curl http://localhost:3000/dashboard

# Check for errors in console
```

### Production Testing
```bash
# Deploy to staging first
npx wrangler deploy --env staging

# Test authentication flow
# - Sign in
# - Access protected routes
# - Sign out
# - Check session persistence
```

---

## Migration from Node.js to Edge

### Step 1: Identify Dependencies
```bash
# Check for Node.js-only dependencies
npm list | grep prisma
npm list | grep mongodb
npm list | grep pg
```

### Step 2: Choose Strategy

**Option A: Keep Node.js runtime**
- Don't migrate to edge
- Use traditional hosting (Node.js)
- No changes needed

**Option B: Switch to JWT sessions**
```typescript
// Before
adapter: PrismaAdapter(prisma),
session: { strategy: "database" },

// After
// Remove adapter
session: { strategy: "jwt" },
```

**Option C: Switch to edge-compatible adapter**
```typescript
// Before
adapter: PrismaAdapter(prisma),

// After
adapter: D1Adapter(env.DB), // or Neon, Upstash, etc.
```

### Step 3: Test Thoroughly
- Test all auth flows (sign in, sign out, session)
- Test protected routes
- Test role-based access
- Test token refresh (if applicable)
- Check error handling

---

## FAQ

**Q: Can I use Prisma in edge runtime?**
A: No, Prisma uses Node.js APIs and binary engines not available in edge runtime. Use Prisma Accelerate or switch to edge-compatible adapter.

**Q: Do I need to use edge runtime?**
A: No, edge runtime is optional. Traditional Node.js hosting works fine. Use edge for better performance and global distribution.

**Q: Can I use database sessions in middleware?**
A: Only if using edge-compatible adapter (D1, Upstash, Neon, etc.). Otherwise, use JWT sessions.

**Q: What's the best approach for beginners?**
A: Use JWT sessions (no adapter). Simplest setup, works everywhere, no edge compatibility issues.

**Q: How do I check if a package is edge-compatible?**
A: Check package docs for "edge runtime" or "Cloudflare Workers" support. Test locally with `wrangler dev` or Next.js edge runtime.

---

**For more information:**
- Auth.js Edge Compatibility: https://authjs.dev/guides/edge-compatibility
- Cloudflare Workers: https://developers.cloudflare.com/workers/
- Next.js Edge Runtime: https://nextjs.org/docs/app/building-your-application/rendering/edge-and-nodejs-runtimes
- Vercel Edge Functions: https://vercel.com/docs/functions/edge-functions
