# Session Strategies: JWT vs Database

**Last Updated**: 2025-10-26
**Auth.js Version**: v5 (next-auth 4.24+)

This guide helps you choose between JWT and database session strategies.

---

## Overview

Auth.js supports two session strategies:

1. **JWT (JSON Web Token)** - Session data in encrypted token
2. **Database** - Session data in database

**Default behavior:**
- No adapter configured: JWT sessions
- Adapter configured: Database sessions (v5 default)

---

## JWT Sessions

### How It Works

1. User signs in
2. Auth.js creates encrypted JWT token
3. Token stored in HTTP-only cookie
4. On each request, token is decrypted
5. Session data extracted from token

**No database queries needed for session retrieval.**

### Configuration

```typescript
export const { handlers, auth } = NextAuth({
  // No adapter = JWT by default
  session: {
    strategy: "jwt",
    maxAge: 30 * 24 * 60 * 60, // 30 days
  },
  providers: [GitHub],
})
```

### Pros ✅

| Advantage | Why It Matters |
|-----------|----------------|
| **Edge compatible** | Works in Cloudflare Workers, Vercel Edge |
| **Fast** | No database queries per request |
| **Scalable** | Stateless, no session storage needed |
| **Simple** | No database setup required |
| **Cost-effective** | No database queries = lower costs |
| **Works offline** | Can validate tokens client-side |

### Cons ❌

| Disadvantage | Why It Matters |
|--------------|----------------|
| **Can't invalidate** | Can't revoke sessions server-side |
| **Size limits** | JWT size ~4KB max (cookie limit) |
| **Data in token** | All session data in client cookie |
| **No audit trail** | Can't track active sessions |
| **Token refresh** | Requires extra logic for long-lived tokens |

### Use Cases

**When to use JWT sessions:**
- ✅ Edge runtime deployment (Cloudflare Workers, Vercel Edge)
- ✅ High-traffic applications (minimize database load)
- ✅ Microservices (stateless, no shared session store)
- ✅ Simple authentication (OAuth only, no complex sessions)
- ✅ Cost optimization (reduce database queries)
- ✅ Next.js middleware (edge runtime requires JWT)

**When NOT to use JWT sessions:**
- ❌ Need to revoke sessions immediately
- ❌ Compliance requires audit trail
- ❌ Large session data (>2KB)
- ❌ Frequently changing session data
- ❌ Multi-tenancy with session isolation

---

## Database Sessions

### How It Works

1. User signs in
2. Auth.js creates session in database
3. Session token stored in HTTP-only cookie
4. On each request, database queried for session
5. Session data retrieved from database

**Requires database adapter.**

### Configuration

```typescript
import { PrismaAdapter } from "@auth/prisma-adapter"

export const { handlers, auth } = NextAuth({
  adapter: PrismaAdapter(prisma), // REQUIRED
  session: {
    strategy: "database",
    maxAge: 30 * 24 * 60 * 60, // 30 days
    updateAge: 24 * 60 * 60, // Update DB every 24 hours
  },
  providers: [GitHub],
})
```

### Pros ✅

| Advantage | Why It Matters |
|-----------|----------------|
| **Full control** | Can invalidate/revoke any session |
| **Audit trail** | Track all active sessions |
| **No size limits** | Store unlimited session data |
| **Secure** | Session data in database, not client |
| **Multi-device** | Track sessions per device |
| **Compliance** | Meets audit requirements |

### Cons ❌

| Disadvantage | Why It Matters |
|--------------|----------------|
| **Database required** | Extra infrastructure |
| **DB query per request** | Slower, higher database load |
| **Not edge-compatible*** | Requires edge-compatible adapter |
| **More complex** | Setup, migrations, maintenance |
| **Higher cost** | Database queries cost money |

**\*Exception:** Works in edge with D1, Upstash, Neon, etc.

### Use Cases

**When to use database sessions:**
- ✅ Need to revoke sessions (security, admin panel)
- ✅ Compliance requires audit trail
- ✅ Track active sessions per user
- ✅ Large session data
- ✅ Frequently changing session data
- ✅ Multi-tenancy with session isolation
- ✅ Magic link authentication (requires adapter)

**When NOT to use database sessions:**
- ❌ Deploying to edge runtime (unless D1/Upstash/etc.)
- ❌ High traffic (database bottleneck)
- ❌ Cost-sensitive (minimize DB queries)
- ❌ Using Credentials provider only (JWT recommended)

---

## Comparison Table

| Feature | JWT Sessions | Database Sessions |
|---------|-------------|-------------------|
| **Setup Complexity** | Simple | Complex |
| **Database Required** | No | Yes |
| **Edge Compatible** | ✅ Always | ⚠️ Adapter-dependent |
| **Performance** | ⭐⭐⭐⭐⭐ Fast | ⭐⭐⭐ Moderate |
| **Scalability** | ⭐⭐⭐⭐⭐ Stateless | ⭐⭐⭐ Database-bound |
| **Cost** | 💰 Low | 💰💰💰 Higher |
| **Invalidate Sessions** | ❌ No | ✅ Yes |
| **Audit Trail** | ❌ No | ✅ Yes |
| **Session Size** | ⚠️ ~4KB max | ✅ Unlimited |
| **Security** | ⭐⭐⭐ Good | ⭐⭐⭐⭐⭐ Excellent |
| **Multi-device Tracking** | ❌ No | ✅ Yes |
| **Credentials Provider** | ✅ Recommended | ⚠️ Requires workaround |
| **Magic Links** | ❌ Requires adapter | ✅ Built-in |

---

## Decision Matrix

### Choose JWT Sessions If:

```
✅ Deploying to edge runtime (Cloudflare, Vercel Edge)
✅ High traffic (>10k requests/hour)
✅ Simple OAuth authentication
✅ Cost optimization priority
✅ Using Next.js middleware
✅ Stateless architecture
✅ No session invalidation needed
```

### Choose Database Sessions If:

```
✅ Need to revoke sessions
✅ Compliance requires audit trail
✅ Track active sessions per user
✅ Magic link authentication
✅ Large or frequently changing session data
✅ Multi-tenancy with session isolation
✅ Traditional Node.js deployment
✅ Edge-compatible adapter (D1, Upstash, etc.)
```

---

## Hybrid Approach

### Use Both Strategies

**Scenario:** Need database adapter (magic links) but also use middleware (edge)

**Solution:** Force JWT sessions even with adapter

```typescript
export const { handlers, auth } = NextAuth({
  adapter: PrismaAdapter(prisma), // For magic links, OAuth accounts
  session: { strategy: "jwt" }, // For middleware compatibility
  providers: [
    Resend, // Requires adapter
    GitHub, // OAuth (works with JWT)
  ],
})
```

**How it works:**
- Adapter stores: Users, accounts, verification tokens
- Sessions: Stored in JWT (edge-compatible)
- Magic links: Work (use verification tokens in DB)
- Middleware: Works (JWT sessions)

**Trade-offs:**
- ✅ Magic links work
- ✅ Middleware works
- ❌ Can't revoke sessions
- ❌ No session audit trail

---

## Migration Between Strategies

### JWT → Database

```typescript
// Before
export const { handlers, auth } = NextAuth({
  session: { strategy: "jwt" },
  providers: [GitHub],
})

// After
import { PrismaAdapter } from "@auth/prisma-adapter"

export const { handlers, auth } = NextAuth({
  adapter: PrismaAdapter(prisma), // Add adapter
  session: { strategy: "database" }, // Switch to database
  providers: [GitHub],
})
```

**Impact:**
- All existing sessions invalidated
- Users need to sign in again
- Database queries on every request

### Database → JWT

```typescript
// Before
export const { handlers, auth } = NextAuth({
  adapter: PrismaAdapter(prisma),
  session: { strategy: "database" },
  providers: [GitHub],
})

// After
export const { handlers, auth } = NextAuth({
  adapter: PrismaAdapter(prisma), // Keep adapter for user accounts
  session: { strategy: "jwt" }, // Switch to JWT
  providers: [GitHub],
})
```

**Impact:**
- All existing sessions invalidated
- Users need to sign in again
- Sessions in database table no longer used
- User accounts still in database

---

## Performance Considerations

### JWT Sessions Performance

```
Request Flow:
1. Receive request (0ms)
2. Read cookie (1ms)
3. Decrypt JWT (5ms)
4. Extract session data (1ms)
Total: ~7ms
```

**Scalability:** Infinite (stateless)

### Database Sessions Performance

```
Request Flow:
1. Receive request (0ms)
2. Read cookie (1ms)
3. Query database (10-50ms)
4. Extract session data (1ms)
Total: ~15-55ms
```

**Scalability:** Limited by database

**Optimization:**
- Use read replicas
- Cache sessions (Redis)
- Connection pooling

---

## Security Considerations

### JWT Sessions Security

**Threats:**
- Token theft (XSS, MitM)
- Token replay
- No revocation

**Mitigations:**
- ✅ HTTP-only cookies (no XSS access)
- ✅ HTTPS only (no MitM)
- ✅ Short expiry times
- ✅ Token rotation
- ⚠️ Can't revoke compromised tokens

### Database Sessions Security

**Threats:**
- Session theft
- Database compromise
- Session fixation

**Mitigations:**
- ✅ HTTP-only cookies
- ✅ HTTPS only
- ✅ Database encryption
- ✅ Can revoke sessions
- ✅ Track suspicious activity
- ✅ Multi-device management

**Winner:** Database sessions (better security controls)

---

## Cost Analysis

### JWT Sessions Cost

```
100,000 requests/day
Database queries: 0
Cost: $0/month (session-wise)
```

### Database Sessions Cost

```
100,000 requests/day
Database queries: 100,000/day = 3M/month
Cost: ~$15-50/month (varies by provider)
```

**Winner:** JWT sessions (significantly cheaper at scale)

---

## Recommendation

### For Most Projects: JWT Sessions

**Why:**
- Simple setup
- Fast performance
- Edge compatible
- Cost-effective
- Sufficient security for most use cases

### Upgrade to Database Sessions When:

1. **Security requirement:** Need to revoke sessions
2. **Compliance requirement:** Need audit trail
3. **Business requirement:** Track active sessions
4. **Technical requirement:** Magic links or large session data

---

## FAQ

**Q: Can I change strategies later?**
A: Yes, but all users will need to sign in again.

**Q: Which is more secure?**
A: Database sessions (can revoke), but JWT is secure enough for most use cases.

**Q: Which is faster?**
A: JWT sessions (no database queries).

**Q: Can I use JWT in edge runtime with Prisma?**
A: Yes, force JWT sessions. Adapter only used for initial sign-in.

**Q: Do I need an adapter for JWT sessions?**
A: No (unless using magic links or database features).

**Q: Can I track active sessions with JWT?**
A: No, JWT sessions are stateless.

**Q: What's best for Cloudflare Workers?**
A: JWT sessions (unless using D1 adapter).

**Q: What's best for Next.js middleware?**
A: JWT sessions (edge runtime requirement).

---

**For more information:**
- Session Management: https://authjs.dev/getting-started/session-management
- JWT Sessions: https://authjs.dev/getting-started/session-management/jwt
- Database Sessions: https://authjs.dev/getting-started/session-management/database
