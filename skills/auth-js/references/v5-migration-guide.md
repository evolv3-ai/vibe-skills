# Auth.js v5 Migration Guide

**Last Updated**: 2025-10-26
**Migrating From**: next-auth v4
**Migrating To**: next-auth v5 (Auth.js v5)

This guide covers all breaking changes and migration steps from Auth.js v4 to v5.

---

## Overview

Auth.js v5 (also called next-auth v5) is a major rewrite with several breaking changes:

**Major Changes:**
1. Package namespace change: `@next-auth/*` → `@auth/*`
2. Unified `auth()` function (replaces `getServerSession`, `getToken`)
3. Session strategy defaults changed
4. JWT encryption improvements (salt added)
5. Edge runtime focus
6. Configuration changes

---

## Breaking Changes Checklist

- [ ] Update package namespaces (@next-auth → @auth)
- [ ] Replace getServerSession with auth()
- [ ] Replace getToken with auth()
- [ ] Update adapter imports
- [ ] Force JWT sessions if using database adapter
- [ ] Update session type definitions
- [ ] Test session persistence (JWT salt changed)
- [ ] Update middleware imports
- [ ] Check provider configurations
- [ ] Update TypeScript types

---

## 1. Package Namespace Changes

### Database Adapters

**v4:**
```bash
npm install @next-auth/prisma-adapter
npm install @next-auth/mongodb-adapter
npm install @next-auth/d1-adapter
```

**v5:**
```bash
npm install @auth/prisma-adapter
npm install @auth/mongodb-adapter
npm install @auth/d1-adapter
```

**Why:** Database adapters don't depend on Next.js, so they moved to framework-agnostic `@auth/*` scope.

### Migration Steps

```bash
# 1. Uninstall old adapters
npm uninstall @next-auth/prisma-adapter

# 2. Install new adapters
npm install @auth/prisma-adapter
```

```typescript
// Update imports
// Before (v4)
import { PrismaAdapter } from "@next-auth/prisma-adapter"

// After (v5)
import { PrismaAdapter } from "@auth/prisma-adapter"
```

---

## 2. Unified auth() Function

### getServerSession → auth()

**v4:**
```typescript
import { getServerSession } from "next-auth/next"
import { authOptions } from "./auth"

export default async function Page() {
  const session = await getServerSession(authOptions)

  if (!session) {
    return <div>Not authenticated</div>
  }

  return <div>Welcome {session.user.name}</div>
}
```

**v5:**
```typescript
import { auth } from "@/auth"

export default async function Page() {
  const session = await auth()

  if (!session) {
    return <div>Not authenticated</div>
  }

  return <div>Welcome {session.user.name}</div>
}
```

**Why:** Simpler API, no need to pass authOptions every time.

### getToken → auth()

**v4:**
```typescript
import { getToken } from "next-auth/jwt"

export async function GET(req: Request) {
  const token = await getToken({ req })

  if (!token) {
    return new Response("Unauthorized", { status: 401 })
  }

  return new Response("Authorized")
}
```

**v5:**
```typescript
import { auth } from "@/auth"

export async function GET() {
  const session = await auth()

  if (!session) {
    return new Response("Unauthorized", { status: 401 })
  }

  return new Response("Authorized")
}
```

**Important:** `auth()` now automatically rotates session expiry when passed the `res` object.

---

## 3. Session Strategy Defaults

### Default Behavior Changed

**v4:**
- No adapter: JWT sessions
- With adapter: JWT sessions (explicit default)

**v5:**
- No adapter: JWT sessions
- **With adapter: DATABASE sessions (NEW DEFAULT)**

### Migration: Force JWT Sessions

**Critical:** If you use middleware or edge runtime, you MUST force JWT sessions:

```typescript
// v5 configuration
export const { handlers, auth } = NextAuth({
  adapter: PrismaAdapter(prisma),
  session: {
    strategy: "jwt", // ✅ REQUIRED for edge compatibility
  },
})
```

**Why:** Database sessions don't work in edge runtime unless using edge-compatible adapter (D1, Upstash, etc.).

---

## 4. JWT Encryption Changes

### Salt Added to Encryption

**v4:** No salt in JWT encryption
**v5:** Salt added for improved security

**Impact:** Existing sessions will be invalidated after migration.

**Solution 1: Invalidate All Sessions**
```typescript
// Simplest approach: Users will need to sign in again
// No code changes needed, just deploy v5
```

**Solution 2: Gradual Migration (Preserve Sessions)**
```typescript
// Custom migration logic (complex, not recommended)
// See: https://medium.com/@sajvanleeuwen/migrating-from-nextauth-v4-to-auth-js-v5-without-logging-out-users-c7ac6bbb0e51
```

**Recommendation:** Accept session invalidation (users sign in again).

---

## 5. Split Configuration Pattern

### New Recommended Pattern

**v5** introduces split configuration for edge compatibility:

```typescript
// auth.config.ts (edge-compatible, no adapter)
import type { NextAuthConfig } from "next-auth"
import GitHub from "next-auth/providers/github"

export default {
  providers: [GitHub],
  // No adapter, no database dependencies
} satisfies NextAuthConfig

// auth.ts (full config with database)
import NextAuth from "next-auth"
import { PrismaAdapter } from "@auth/prisma-adapter"
import authConfig from "./auth.config"

export const { handlers, auth, signIn, signOut } = NextAuth({
  adapter: PrismaAdapter(prisma),
  session: { strategy: "jwt" }, // Force JWT for middleware
  ...authConfig,
})
```

**Why:** Allows middleware (edge runtime) to work while still using database adapter in server code.

---

## 6. TypeScript Type Changes

### Session Types

**v4:**
```typescript
import { Session } from "next-auth"
import { JWT } from "next-auth/jwt"
```

**v5:**
```typescript
import type { Session } from "next-auth"
import type { JWT } from "next-auth/jwt"
```

### Module Augmentation

**v4:**
```typescript
declare module "next-auth" {
  interface Session {
    user: {
      id: string
      role: string
    } & DefaultSession["user"]
  }
}
```

**v5:** (same, but with better type inference)
```typescript
declare module "next-auth" {
  interface Session {
    user: {
      id: string
      role: string
    } & DefaultSession["user"]
  }
}
```

---

## 7. Middleware Changes

### Import Changes

**v4:**
```typescript
export { default } from "next-auth/middleware"
```

**v5:**
```typescript
export { auth as middleware } from "@/auth"
```

### Advanced Middleware

**v4:**
```typescript
import { withAuth } from "next-auth/middleware"

export default withAuth({
  callbacks: {
    authorized({ req, token }) {
      return !!token
    },
  },
})
```

**v5:**
```typescript
import { auth } from "@/auth"

export default auth((req) => {
  if (!req.auth) {
    return Response.redirect(new URL("/login", req.url))
  }
})
```

---

## 8. Credentials Provider

### No Breaking Changes

Credentials provider works the same in v5, but remember:

**Critical Rules (same in v4 and v5):**
1. **NEVER throw errors** in `authorize()` - return `null`
2. **ONLY works with JWT sessions**
3. **Validate with Zod** before checking credentials

---

## 9. Provider Changes

### Most Providers Unchanged

OAuth providers (GitHub, Google, etc.) work the same.

**Import change:**
```typescript
// v4
import GitHubProvider from "next-auth/providers/github"

// v5
import GitHub from "next-auth/providers/github"
// Note: No "Provider" suffix
```

---

## 10. Callback Changes

### Callbacks Work the Same

**No breaking changes** in callback functions:
- `signIn()`
- `redirect()`
- `jwt()`
- `session()`

**But:** Be aware of edge compatibility if using database queries in callbacks.

---

## Complete Migration Example

### Before (v4)

```typescript
// pages/api/auth/[...nextauth].ts
import NextAuth, { AuthOptions } from "next-auth"
import GitHubProvider from "next-auth/providers/github"
import { PrismaAdapter } from "@next-auth/prisma-adapter"
import { prisma } from "@/lib/prisma"

export const authOptions: AuthOptions = {
  adapter: PrismaAdapter(prisma),
  providers: [
    GitHubProvider({
      clientId: process.env.GITHUB_ID,
      clientSecret: process.env.GITHUB_SECRET,
    }),
  ],
  callbacks: {
    async session({ session, user }) {
      session.user.id = user.id
      return session
    },
  },
}

export default NextAuth(authOptions)
```

```typescript
// pages/dashboard.tsx
import { getServerSession } from "next-auth/next"
import { authOptions } from "./api/auth/[...nextauth]"

export async function getServerSideProps(context) {
  const session = await getServerSession(context.req, context.res, authOptions)

  if (!session) {
    return { redirect: { destination: "/login" } }
  }

  return { props: { session } }
}
```

### After (v5)

```typescript
// auth.ts
import NextAuth from "next-auth"
import GitHub from "next-auth/providers/github"
import { PrismaAdapter } from "@auth/prisma-adapter"
import { prisma } from "@/lib/prisma"

export const { handlers, auth, signIn, signOut } = NextAuth({
  adapter: PrismaAdapter(prisma),
  session: { strategy: "jwt" }, // NEW: Force JWT for edge
  providers: [
    GitHub({
      clientId: process.env.AUTH_GITHUB_ID,
      clientSecret: process.env.AUTH_GITHUB_SECRET,
    }),
  ],
  callbacks: {
    async jwt({ token, user }) {
      if (user) {
        token.id = user.id
      }
      return token
    },
    async session({ session, token }) {
      session.user.id = token.id as string
      return session
    },
  },
})
```

```typescript
// app/api/auth/[...nextauth]/route.ts
import { handlers } from "@/auth"
export const { GET, POST } = handlers
```

```typescript
// app/dashboard/page.tsx
import { auth } from "@/auth"
import { redirect } from "next/navigation"

export default async function Dashboard() {
  const session = await auth()

  if (!session) {
    redirect("/login")
  }

  return <div>Welcome {session.user.name}</div>
}
```

```typescript
// middleware.ts
export { auth as middleware } from "@/auth"

export const config = {
  matcher: ["/((?!api|_next/static|_next/image|favicon.ico).*)"],
}
```

---

## Step-by-Step Migration

### Phase 1: Update Packages

```bash
# Update next-auth
npm install next-auth@latest @auth/core@latest

# Update adapters
npm uninstall @next-auth/prisma-adapter
npm install @auth/prisma-adapter@latest

# Update Next.js (recommended)
npm install next@latest react@latest react-dom@latest
```

### Phase 2: Update Configuration

1. Create `auth.ts` in project root
2. Move configuration from `pages/api/auth/[...nextauth].ts`
3. Export `{ handlers, auth, signIn, signOut }`
4. Force JWT sessions if using adapter
5. Update provider imports (remove "Provider" suffix)

### Phase 3: Update API Route

```typescript
// app/api/auth/[...nextauth]/route.ts
import { handlers } from "@/auth"
export const { GET, POST } = handlers
```

### Phase 4: Replace getServerSession

Find and replace all instances:
```bash
# Search for
getServerSession(authOptions)
getServerSession(req, res, authOptions)

# Replace with
await auth()
```

### Phase 5: Update Middleware

```typescript
// middleware.ts
export { auth as middleware } from "@/auth"
```

### Phase 6: Update TypeScript

Ensure type augmentation is in `auth.ts` or separate file:
```typescript
declare module "next-auth" {
  interface Session {
    user: {
      id: string
    } & DefaultSession["user"]
  }
}
```

### Phase 7: Test

- [ ] Sign in works
- [ ] Sign out works
- [ ] Session persists
- [ ] Protected routes work
- [ ] Middleware works
- [ ] Callbacks work
- [ ] Role-based access works (if applicable)
- [ ] Database writes work (if using adapter)

---

## Common Migration Issues

### Issue 1: Session Invalid After Migration

**Cause:** JWT encryption salt changed
**Fix:** Users need to sign in again (expected behavior)

### Issue 2: Middleware Errors

**Cause:** Using database sessions without edge-compatible adapter
**Fix:** Force JWT sessions in config

### Issue 3: getServerSession Not Found

**Cause:** Using v4 API in v5
**Fix:** Replace with `auth()` function

### Issue 4: Adapter Import Error

**Cause:** Using old @next-auth/* namespace
**Fix:** Update to @auth/* namespace

---

## Rollback Plan

If migration fails:

```bash
# Revert to v4
npm install next-auth@4

# Revert adapter
npm uninstall @auth/prisma-adapter
npm install @next-auth/prisma-adapter
```

**Recommendation:** Test migration thoroughly in staging before production.

---

## Resources

**Official Docs:**
- Migration Guide: https://authjs.dev/getting-started/migrating-to-v5
- v5 Announcement: https://github.com/nextauthjs/next-auth/discussions/8487

**Community Resources:**
- DEV Community Guide: https://dev.to/acetoolz/nextauthjs-v5-guide-migrating-from-v4-with-real-examples-50ad
- Medium Article: https://medium.com/@sajvanleeuwen/migrating-from-nextauth-v4-to-auth-js-v5-without-logging-out-users-c7ac6bbb0e51
- Best Features: https://medium.com/@ppriyank40/best-features-of-auth-js-v5-formerly-known-as-next-auth-d59e14938471

**Support:**
- GitHub Discussions: https://github.com/nextauthjs/next-auth/discussions
- GitHub Issues: https://github.com/nextauthjs/next-auth/issues
