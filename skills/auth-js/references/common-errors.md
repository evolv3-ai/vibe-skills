# Common Auth.js Errors & Fixes

**Last Updated**: 2025-10-26
**Auth.js Version**: v5 (next-auth 4.24+)

This document lists all known Auth.js errors with root causes, fixes, and prevention strategies.

---

## 1. Missing AUTH_SECRET

### Error Message
```
Error: AUTH_SECRET environment variable is not set
JWEDecryptionFailed: Invalid Compact JWE
```

### Root Cause
- Auth.js requires `AUTH_SECRET` to encrypt JWTs and hash email verification tokens
- Changed secret but still have active session with old secret
- Missing in production environment

### Fix
```bash
# Generate secret
npx auth secret

# Add to .env.local (development)
AUTH_SECRET=your-generated-secret

# Add to production environment
# Vercel: Settings → Environment Variables
# Cloudflare: wrangler secret put AUTH_SECRET
# Other hosts: Add to environment variables
```

### Prevention
- Always set AUTH_SECRET before first deployment
- Never commit AUTH_SECRET to git
- Use different secrets for dev/staging/production
- Document in .env.example

### Source
- https://authjs.dev/reference/core/errors
- https://github.com/nextauthjs/next-auth/issues/8488

---

## 2. CallbackRouteError

### Error Message
```
CallbackRouteError: Illegal arguments: string, undefined
CallbackRouteError: Read more at https://errors.authjs.dev#callbackrouteerror
```

### Root Cause
**Throwing errors in the `authorize()` callback** instead of returning `null`

When you throw an error in the Credentials provider's `authorize()` callback, Auth.js wraps it as a `CallbackRouteError` instead of the expected `CredentialsSignin` error.

### Fix

**WRONG:**
```typescript
authorize: async (credentials) => {
  const user = await getUserFromDb(credentials.email)

  if (!user) {
    throw new Error("User not found") // ❌ CAUSES CallbackRouteError
  }

  return user
}
```

**CORRECT:**
```typescript
authorize: async (credentials) => {
  const user = await getUserFromDb(credentials.email)

  if (!user) {
    return null // ✅ CORRECT - returns CredentialsSignin
  }

  return user
}
```

### Prevention
- **ALWAYS return `null`** for invalid credentials
- **NEVER throw errors** in `authorize()`
- Use try/catch and return `null` on error
- Log errors for debugging (console.log/console.error)

### Source
- https://github.com/nextauthjs/next-auth/issues/9603
- https://neuraldemy.com/fixedcallbackrouteerror-credentialssignin-error/
- https://medium.com/@beecodeguy/debugging-the-next-js-errors-auth-js-bd24c58d35f7

---

## 3. Route Not Found

### Error Message
```
Error: next-auth route not found
404 Not Found: /api/auth/signin
```

### Root Cause
- API route handler file not at correct path
- File named incorrectly
- Next.js not detecting the dynamic route

### Fix

**Ensure file is at EXACT path:**
```
app/api/auth/[...nextauth]/route.ts
```

**File contents:**
```typescript
import { handlers } from "@/auth"
export const { GET, POST } = handlers
```

**Check for typos:**
- ✅ `[...nextauth]` (lowercase, square brackets, spread operator)
- ❌ `[...nextAuth]` (wrong case)
- ❌ `[nextauth]` (missing spread operator)
- ❌ `{...nextauth}` (curly braces instead of square)

### Prevention
- Use exact file structure from Auth.js docs
- Test route exists: `curl http://localhost:3000/api/auth/providers`
- Check Next.js routing docs for App Router vs Pages Router

### Source
- https://www.omi.me/blogs/next-js-errors/error-next-auth-route-not-found-in-next-js-causes-and-how-to-fix
- https://github.com/nextauthjs/next-auth/issues/7658

---

## 4. Edge Runtime Compatibility Error

### Error Message
```
Error: The edge runtime does not support Node.js 'crypto' module
Module not compatible with edge runtime
Dynamic Code Evaluation (e. g. 'eval', 'new Function') not allowed in Edge Runtime
```

### Root Cause
- Using database adapter that's not edge-compatible (Prisma, TypeORM, etc.)
- Using `session: { strategy: "database" }` with non-edge adapter
- Importing Node.js-specific modules in middleware

### Fix

**Option 1: Force JWT sessions (recommended)**
```typescript
export const { handlers, auth } = NextAuth({
  adapter: PrismaAdapter(prisma), // Not edge-compatible
  session: { strategy: "jwt" }, // ✅ Force JWT for edge
})
```

**Option 2: Split configuration**
```typescript
// auth.config.ts (edge-compatible)
export default {
  providers: [GitHub],
} satisfies NextAuthConfig

// auth.ts (full config with database)
import authConfig from "./auth.config"

export const { handlers, auth } = NextAuth({
  adapter: PrismaAdapter(prisma),
  session: { strategy: "jwt" },
  ...authConfig,
})

// middleware.ts (uses edge-compatible config)
import authConfig from "./auth.config"
export const { auth: middleware } = NextAuth(authConfig)
```

**Option 3: Use edge-compatible adapter**
```typescript
// D1 adapter is edge-compatible
import { D1Adapter } from "@auth/d1-adapter"

export const { handlers, auth } = NextAuth({
  adapter: D1Adapter(env.DB), // ✅ Edge-compatible
  session: { strategy: "database" }, // Can use database sessions
})
```

### Prevention
- Check adapter compatibility before using
- Default to JWT sessions unless you need database sessions
- Split config for edge middleware
- Use D1 adapter for Cloudflare Workers

### Source
- https://authjs.dev/guides/edge-compatibility
- https://github.com/nextauthjs/next-auth/issues/11423
- https://github.com/better-auth/better-auth/issues/1143

---

## 5. PKCE Configuration Error

### Error Message
```
PKCE Error: Code verifier expired
PKCE Error: Invalid code_challenge
```

### Root Cause
- OAuth provider PKCE (Proof Key for Code Exchange) flow timing out
- Code verifier cookie expired (15 min default)
- PKCE not supported by provider
- Cookie issues (domain, SameSite, secure)

### Fix

**Check provider support:**
- GitHub: PKCE supported
- Google: PKCE supported
- Some older providers: May not support PKCE

**Cookie configuration:**
```typescript
export const { handlers, auth } = NextAuth({
  cookies: {
    pkceCodeVerifier: {
      name: "next-auth.pkce.code_verifier",
      options: {
        httpOnly: true,
        sameSite: "lax",
        path: "/",
        secure: process.env.NODE_ENV === "production",
        maxAge: 60 * 15, // 15 minutes
      },
    },
  },
})
```

**Check environment:**
```bash
# Ensure NEXTAUTH_URL is set correctly
NEXTAUTH_URL=http://localhost:3000 # Development
NEXTAUTH_URL=https://yourdomain.com # Production
```

### Prevention
- Don't take longer than 15 minutes between sign-in initiation and callback
- Ensure cookies are enabled in browser
- Check provider's OAuth documentation for PKCE requirements
- Test in production environment (cookies behave differently)

### Source
- https://next-auth.js.org/errors
- https://authjs.dev/reference/core/errors

---

## 6. Session Not Updating

### Error Message
```
Session expired but not refreshing
Session data is stale
```

### Root Cause
- Missing middleware (no automatic session refresh)
- Session update not triggered
- Cache not invalidated

### Fix

**Add middleware:**
```typescript
// middleware.ts
export { auth as middleware } from "@/auth"

export const config = {
  matcher: ["/((?!api|_next/static|_next/image|favicon.ico).*)"],
}
```

**Force session update (client-side):**
```typescript
import { useSession } from "next-auth/react"

const { update } = useSession()

// Manually trigger session update
await update()
```

**Force session update (server-side):**
```typescript
import { auth } from "@/auth"
import { revalidatePath } from "next/cache"

// In Server Action
const session = await auth()
// Make changes to user data
revalidatePath("/")
```

### Prevention
- Always add middleware for session management
- Use `update()` after making changes to user data
- Configure `updateAge` in session config
- Revalidate paths after data changes

### Source
- https://authjs.dev/getting-started/installation
- https://nextjs.org/docs/app/building-your-application/data-fetching/caching#revalidating-data

---

## 7. Database Strategy Not Working

### Error Message
```
Database session strategy requires an adapter
TypeError: Cannot read property 'getSessionAndUser' of undefined
```

### Root Cause
- Using `session: { strategy: "database" }` without adapter
- Adapter not edge-compatible in middleware
- Database connection issues

### Fix

**Add adapter:**
```typescript
import { PrismaAdapter } from "@auth/prisma-adapter"

export const { handlers, auth } = NextAuth({
  adapter: PrismaAdapter(prisma), // REQUIRED for database sessions
  session: { strategy: "database" },
})
```

**Or force JWT sessions:**
```typescript
export const { handlers, auth } = NextAuth({
  // No adapter
  session: { strategy: "jwt" }, // Use JWT instead
})
```

### Prevention
- Database strategy requires adapter
- JWT strategy works without adapter
- Check edge compatibility before using database sessions
- Default to JWT for simplicity

### Source
- https://authjs.dev/getting-started/session-management/database
- https://stackoverflow.com/questions/78577647/auth-js-v5-database-session-strategy-for-credential-provider-returning-null

---

## 8. v5 Migration Issues

### Error Message
```
Error: @next-auth/prisma-adapter is not supported in v5
Module "@auth/core/providers/credentials" not found
```

### Root Cause
- Using deprecated v4 packages
- Namespace changes from @next-auth to @auth
- JWT encryption salt changes
- API changes (getServerSession → auth)

### Fix

**Update adapter namespaces:**
```bash
# WRONG (v4)
npm install @next-auth/prisma-adapter

# CORRECT (v5)
npm install @auth/prisma-adapter
```

**Update imports:**
```typescript
// WRONG (v4)
import { getServerSession } from "next-auth/next"

// CORRECT (v5)
import { auth } from "@/auth"
```

**Update session strategy:**
```typescript
// v5 defaults to database strategy if adapter is present
export const { handlers, auth } = NextAuth({
  adapter: PrismaAdapter(prisma),
  session: { strategy: "jwt" }, // Force JWT for edge
})
```

### Prevention
- Read migration guide before upgrading
- Update all @next-auth/* packages to @auth/*
- Test thoroughly after migration
- May need to invalidate existing sessions (JWT salt changed)

### Source
- https://authjs.dev/getting-started/migrating-to-v5
- https://dev.to/acetoolz/nextauthjs-v5-guide-migrating-from-v4-with-real-examples-50ad
- https://medium.com/@sajvanleeuwen/migrating-from-nextauth-v4-to-auth-js-v5-without-logging-out-users-c7ac6bbb0e51

---

## 9. D1 Binding Errors (Cloudflare Workers)

### Error Message
```
Error: Cannot read properties of undefined (reading 'prepare')
D1_ERROR: Database not found
Uncaught TypeError: env.DB is undefined
```

### Root Cause
- Database binding name mismatch in wrangler.jsonc
- Database not created
- Migrations not run
- Accessing binding outside request context

### Fix

**Check wrangler.jsonc:**
```jsonc
{
  "d1_databases": [
    {
      "binding": "DB", // Must match code
      "database_name": "auth_db",
      "database_id": "your-database-id"
    }
  ]
}
```

**Create database:**
```bash
npx wrangler d1 create auth_db
# Copy database_id to wrangler.jsonc
```

**Run migrations:**
```bash
npx wrangler d1 execute auth_db --file=./schema.sql
```

**Access binding correctly:**
```typescript
// WRONG - binding not available globally
const adapter = D1Adapter(env.DB)

// CORRECT - access binding from request context
app.all('/api/auth/*', async (c) => {
  return await Auth(c.req.raw, {
    adapter: D1Adapter(c.env.DB), // ✅ From request context
  })
})
```

### Prevention
- Always create D1 database before deploying
- Run migrations locally and in production
- Match binding names in wrangler.jsonc and code
- Access bindings from request context, not globally

### Source
- https://authjs.dev/getting-started/adapters/d1
- https://developers.cloudflare.com/d1/
- https://github.com/nextauthjs/next-auth/issues/5918

---

## 10. Credentials with Database Sessions

### Error Message
```
Credentials provider is not compatible with database sessions
JWT must be enabled to use credentials provider
```

### Root Cause
- Credentials provider **ONLY** supports JWT sessions
- Trying to use database sessions with Credentials

### Fix

**Force JWT sessions:**
```typescript
import Credentials from "next-auth/providers/credentials"

export const { handlers, auth } = NextAuth({
  providers: [Credentials({ /* ... */ })],
  session: { strategy: "jwt" }, // REQUIRED
})
```

**Alternative: Manual database session creation**
```typescript
// Not recommended - requires custom implementation
// Use JWT sessions instead
```

### Prevention
- Always use JWT sessions with Credentials provider
- Don't configure adapter when using only Credentials
- If you need database tracking, log sign-ins separately

### Source
- https://next-auth.js.org/configuration/providers/credentials
- https://authjs.dev/getting-started/providers/credentials

---

## 11. Production Deployment Failures

### Error Message
```
Error: AUTH_SECRET is not set
Error: Adapter is not defined
Error: Invalid callback URL
```

### Root Cause
- Missing environment variables in production
- Different URLs between dev and production
- Adapter/database not configured in production
- OAuth callback URLs not updated

### Fix

**Check all environment variables:**
```bash
# Required
AUTH_SECRET=...
AUTH_GITHUB_ID=...
AUTH_GITHUB_SECRET=...

# If using database
DATABASE_URL=...

# If using magic links
AUTH_RESEND_KEY=...

# Production URL
NEXTAUTH_URL=https://yourdomain.com
```

**Update OAuth callback URLs:**
```
Development: http://localhost:3000/api/auth/callback/github
Production: https://yourdomain.com/api/auth/callback/github
```

**Test locally with production URLs:**
```bash
# Test with production-like environment
NEXTAUTH_URL=https://yourdomain.com npm run dev
```

### Prevention
- Document all required environment variables
- Use .env.example file
- Test with production environment variables locally
- Update OAuth callback URLs before deploying
- Use different OAuth apps for dev/production

### Source
- https://authjs.dev/getting-started/deployment
- https://stackoverflow.com/questions/68029244/how-to-fix-api-auth-error-issue-of-next-auth-in-production

---

## 12. JSON Expected But HTML Received

### Error Message
```
Unexpected token '<', "<!DOCTYPE "... is not valid JSON
Expected JSON response but received HTML
```

### Root Cause
- Next.js 15 rewrites configuration issue
- Auth.js route being rewritten
- Incorrect API route setup

### Fix

**Check next.config.js rewrites:**
```javascript
module.exports = {
  async rewrites() {
    return {
      beforeFiles: [
        // Don't rewrite auth routes
        {
          source: '/api/auth/:path*',
          destination: '/api/auth/:path*',
        },
      ],
    }
  },
}
```

**Verify route handler:**
```typescript
// app/api/auth/[...nextauth]/route.ts
import { handlers } from "@/auth"
export const { GET, POST } = handlers
```

### Prevention
- Don't rewrite /api/auth/* routes
- Test auth routes return JSON (curl or browser)
- Check Next.js version compatibility
- Review middleware matchers

### Source
- https://github.com/nextauthjs/next-auth/issues/9385
- https://medium.com/@beecodeguy/debugging-the-next-js-errors-auth-js-bd24c58d35f7

---

## Quick Reference Table

| Error | Cause | Fix |
|-------|-------|-----|
| Missing AUTH_SECRET | No secret configured | `npx auth secret` |
| CallbackRouteError | Throwing in authorize() | Return `null` instead |
| Route not found | Wrong file path | Use `app/api/auth/[...nextauth]/route.ts` |
| Edge incompatibility | Non-edge adapter | Force JWT sessions |
| PKCE error | Timeout or cookies | Check provider support |
| Session not updating | No middleware | Add middleware.ts |
| Database strategy fails | No adapter | Add adapter or use JWT |
| v5 migration issues | Namespace changes | Update to @auth/* packages |
| D1 binding error | Database not created | Create database + run migrations |
| Credentials + database | Incompatible | Use JWT sessions |
| Production failure | Missing env vars | Set AUTH_SECRET + callbacks |
| JSON/HTML error | Rewrites issue | Exclude /api/auth/* from rewrites |

---

**For more errors and updates, see:**
- Official Error Reference: https://authjs.dev/reference/core/errors
- GitHub Issues: https://github.com/nextauthjs/next-auth/issues
