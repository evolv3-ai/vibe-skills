# JWT Customization & Token Management

**Last Updated**: 2025-10-26
**Auth.js Version**: v5 (next-auth 4.24+)

This guide covers JWT customization, custom claims, token refresh, and advanced token management patterns.

---

## JWT Basics

### What Gets Stored in JWT?

**Default JWT payload:**
```json
{
  "sub": "user-id",
  "name": "User Name",
  "email": "user@example.com",
  "picture": "https://avatar.url",
  "iat": 1234567890,
  "exp": 1237159890
}
```

**Custom claims via callbacks:**
- Add user ID, role, permissions
- Add OAuth access tokens
- Add refresh tokens
- Add custom user data

---

## JWT vs Session Callbacks

### Understanding the Flow

```
Sign In:
1. User authenticates
2. jwt() callback runs → Add data to token
3. Token encrypted and stored in cookie

Subsequent Requests:
1. Token decrypted
2. session() callback runs → Expose data to session
3. Session available to app
```

**Key principle:**
- `jwt()` stores data IN the token
- `session()` exposes data FROM the token

---

## Adding Custom Claims

### Pattern 1: User ID and Role

```typescript
import NextAuth from "next-auth"
import type { JWT } from "next-auth/jwt"

export const { handlers, auth } = NextAuth({
  providers: [GitHub],
  callbacks: {
    /**
     * JWT Callback
     * Runs on sign-in and every request
     */
    async jwt({ token, user, account, trigger }) {
      // On sign-in: user object is available
      if (user) {
        token.id = user.id
        token.role = user.role
      }

      return token
    },

    /**
     * Session Callback
     * Runs on every request
     */
    async session({ session, token }) {
      // Expose JWT claims to session
      session.user.id = token.id as string
      session.user.role = token.role as string

      return session
    },
  },
})

/**
 * TypeScript augmentation
 */
declare module "next-auth" {
  interface Session {
    user: {
      id: string
      role: string
    } & DefaultSession["user"]
  }

  interface User {
    role: string
  }
}

declare module "next-auth/jwt" {
  interface JWT {
    id: string
    role: string
  }
}
```

**Usage in app:**
```typescript
const session = await auth()
console.log(session.user.id) // "user-123"
console.log(session.user.role) // "admin"
```

---

## OAuth Access Tokens

### Pattern: Store Access Token in JWT

```typescript
export const { handlers, auth } = NextAuth({
  providers: [GitHub],
  callbacks: {
    async jwt({ token, account }) {
      // On first sign-in, save access token
      if (account) {
        token.accessToken = account.access_token
        token.provider = account.provider
      }

      return token
    },

    async session({ session, token }) {
      // Expose access token to session
      session.accessToken = token.accessToken as string
      return session
    },
  },
})

declare module "next-auth" {
  interface Session {
    accessToken: string
  }
}

declare module "next-auth/jwt" {
  interface JWT {
    accessToken?: string
    provider?: string
  }
}
```

**Use case:** Call GitHub API on behalf of user

```typescript
const session = await auth()

const response = await fetch("https://api.github.com/user/repos", {
  headers: {
    Authorization: `Bearer ${session.accessToken}`,
  },
})
```

---

## Token Refresh Patterns

### Pattern 1: OAuth Token Refresh (Google)

**Full implementation:**

```typescript
export const { handlers, auth } = NextAuth({
  providers: [
    Google({
      authorization: {
        params: {
          prompt: "consent",
          access_type: "offline",
          response_type: "code",
        },
      },
    }),
  ],
  callbacks: {
    async jwt({ token, account }) {
      // First-time sign-in: save tokens
      if (account) {
        return {
          ...token,
          access_token: account.access_token,
          expires_at: account.expires_at,
          refresh_token: account.refresh_token,
        }
      }

      // Subsequent requests: check if token expired
      if (Date.now() < (token.expires_at as number) * 1000) {
        return token // Still valid
      }

      // Token expired: refresh it
      try {
        const response = await fetch("https://oauth2.googleapis.com/token", {
          method: "POST",
          body: new URLSearchParams({
            client_id: process.env.AUTH_GOOGLE_ID!,
            client_secret: process.env.AUTH_GOOGLE_SECRET!,
            grant_type: "refresh_token",
            refresh_token: token.refresh_token as string,
          }),
        })

        const refreshedTokens = await response.json()

        if (!response.ok) throw refreshedTokens

        return {
          ...token,
          access_token: refreshedTokens.access_token,
          expires_at: Math.floor(Date.now() / 1000 + refreshedTokens.expires_in),
          refresh_token: refreshedTokens.refresh_token ?? token.refresh_token,
        }
      } catch (error) {
        console.error("Error refreshing access token", error)
        return { ...token, error: "RefreshAccessTokenError" }
      }
    },

    async session({ session, token }) {
      session.accessToken = token.access_token as string
      session.error = token.error as string | undefined
      return session
    },
  },
})
```

**Client-side error handling:**

```typescript
"use client"
import { useSession, signIn } from "next-auth/react"
import { useEffect } from "react"

export default function Component() {
  const { data: session } = useSession()

  useEffect(() => {
    if (session?.error === "RefreshAccessTokenError") {
      // Force re-authentication
      signIn("google")
    }
  }, [session])

  return <div>...</div>
}
```

---

## Dynamic JWT Updates

### Pattern 1: Update JWT on Session Update

```typescript
export const { handlers, auth } = NextAuth({
  providers: [GitHub],
  callbacks: {
    async jwt({ token, trigger, session }) {
      // On sign-in
      if (user) {
        token.credits = user.credits
      }

      // On session update (from client)
      if (trigger === "update" && session?.credits) {
        token.credits = session.credits
      }

      return token
    },

    async session({ session, token }) {
      session.user.credits = token.credits as number
      return session
    },
  },
})
```

**Client-side update:**

```typescript
"use client"
import { useSession } from "next-auth/react"

export default function Component() {
  const { data: session, update } = useSession()

  const addCredits = async () => {
    // Update in database
    await fetch("/api/credits", { method: "POST" })

    // Update session
    await update({ credits: session.user.credits + 10 })
  }

  return <button onClick={addCredits}>Add Credits</button>
}
```

---

## Permissions & Scopes

### Pattern 1: Permission Array

```typescript
type Permission = "read" | "write" | "delete" | "admin"

export const { handlers, auth } = NextAuth({
  providers: [GitHub],
  callbacks: {
    async jwt({ token, user }) {
      if (user) {
        // Get permissions from database or compute based on role
        const permissions: Permission[] =
          user.role === "admin"
            ? ["read", "write", "delete", "admin"]
            : user.role === "moderator"
            ? ["read", "write", "delete"]
            : ["read", "write"]

        token.permissions = permissions
      }

      return token
    },

    async session({ session, token }) {
      session.user.permissions = token.permissions as Permission[]
      return session
    },
  },
})
```

**Usage:**

```typescript
const session = await auth()

if (session.user.permissions.includes("delete")) {
  // Show delete button
}
```

---

## Multi-Tenancy

### Pattern: Tenant ID in JWT

```typescript
export const { handlers, auth } = NextAuth({
  providers: [GitHub],
  callbacks: {
    async jwt({ token, user, trigger, session }) {
      // On sign-in: get user's default tenant
      if (user) {
        const userTenant = await db.userTenant.findFirst({
          where: { userId: user.id, isDefault: true },
        })
        token.tenantId = userTenant?.tenantId
      }

      // On tenant switch (from client)
      if (trigger === "update" && session?.tenantId) {
        // Verify user has access to this tenant
        const hasAccess = await db.userTenant.findFirst({
          where: {
            userId: token.sub,
            tenantId: session.tenantId,
          },
        })

        if (hasAccess) {
          token.tenantId = session.tenantId
        }
      }

      return token
    },

    async session({ session, token }) {
      session.user.tenantId = token.tenantId as string
      return session
    },
  },
})
```

**Switch tenant:**

```typescript
const { update } = useSession()

await update({ tenantId: "new-tenant-id" })
```

---

## JWT Size Optimization

### Problem: JWT Too Large

**Symptoms:**
- Cookie size exceeds 4KB limit
- Headers too large error
- Authentication fails randomly

**Solutions:**

**1. Store only IDs, not full objects:**

```typescript
// BAD (large JWT)
token.user = {
  id: "123",
  name: "John Doe",
  email: "john@example.com",
  avatar: "https://...",
  bio: "Long bio text...",
  preferences: { theme: "dark", ... },
}

// GOOD (small JWT)
token.userId = "123" // Look up full user in database when needed
```

**2. Use database for large data:**

```typescript
async session({ session, token }) {
  // Fetch full user data from database
  const user = await db.user.findUnique({
    where: { id: token.sub },
  })

  session.user = user
  return session
}
```

**3. Compress arrays:**

```typescript
// Store permission IDs, not full permission objects
token.permissionIds = [1, 2, 3] // Instead of full permission objects
```

---

## Debugging JWT

### Pattern: Inspect JWT Token

```typescript
async jwt({ token, user }) {
  console.log("JWT Payload:", {
    size: JSON.stringify(token).length,
    claims: Object.keys(token),
    token,
  })

  return token
}
```

### Decode JWT Manually

```bash
# Get token from cookie (browser DevTools)
# Paste into https://jwt.io

# Or decode in Node.js
import { decode } from "next-auth/jwt"

const token = await decode({
  token: "your-jwt-token",
  secret: process.env.AUTH_SECRET!,
})

console.log(token)
```

---

## Security Best Practices

### ✅ Do:

1. **Keep JWT small** (< 2KB)
   - Only essential data
   - Use IDs, not full objects

2. **Set short expiry** (1-7 days)
   - Reduces risk if token stolen
   - Use refresh tokens for long sessions

3. **Encrypt sensitive data**
   - JWT is base64 encoded, not encrypted
   - Auth.js encrypts JWT by default

4. **Validate on every request**
   - Don't trust client claims
   - Re-verify critical data

5. **Rotate tokens**
   - Update expiry on each request
   - Force re-authentication periodically

### ❌ Don't:

1. **Don't store passwords**
   - Never store credentials in JWT
   - Not even hashed

2. **Don't store sensitive PII**
   - Credit cards, SSN, health data
   - JWT is not encrypted end-to-end

3. **Don't make JWT too large**
   - Keep under 4KB
   - Exceeds cookie size limits

4. **Don't expose secrets**
   - API keys, database credentials
   - Use server-side only

5. **Don't trust client-side JWT**
   - Can be manipulated
   - Always verify on server

---

## Common Patterns Summary

| Pattern | Use Case |
|---------|----------|
| **User ID + Role** | Basic user data in session |
| **Access Token Storage** | Call OAuth APIs on behalf of user |
| **Token Refresh** | Keep OAuth tokens fresh |
| **Dynamic Updates** | Update session without sign-out |
| **Permissions Array** | Granular access control |
| **Tenant ID** | Multi-tenancy support |
| **Size Optimization** | Avoid JWT size limits |

---

## FAQ

**Q: What's the maximum JWT size?**
A: ~4KB (cookie limit). Keep under 2KB to be safe.

**Q: Can I invalidate a JWT?**
A: No, JWTs are stateless. Use database sessions if you need this.

**Q: How do I force a user to re-authenticate?**
A: Set short expiry or implement token revocation list (complex).

**Q: Can I store the JWT in localStorage?**
A: No, Auth.js uses HTTP-only cookies (more secure).

**Q: How do I debug JWT issues?**
A: Log in `jwt()` callback, decode token at jwt.io.

**Q: What if my JWT exceeds 4KB?**
A: Store less data in JWT, use database for full user object.

---

**For more information:**
- JWT Callbacks: https://authjs.dev/reference/core/types#jwt
- Session Callbacks: https://authjs.dev/reference/core/types#session
- JWT Debugging: https://jwt.io
