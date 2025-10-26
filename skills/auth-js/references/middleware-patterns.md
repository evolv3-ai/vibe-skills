# Middleware Patterns & Route Protection

**Last Updated**: 2025-10-26
**Auth.js Version**: v5 (next-auth 4.24+)
**Framework**: Next.js 15+ (App Router)

This guide covers middleware patterns for route protection, session management, and role-based access control.

---

## Basic Middleware Setup

### Simple Session Keep-Alive

**Purpose:** Automatically refresh session expiry on every request

```typescript
// middleware.ts
export { auth as middleware } from "@/auth"

export const config = {
  matcher: ["/((?!api|_next/static|_next/image|favicon.ico).*)"],
}
```

**What it does:**
- Updates session expiry on every request
- No custom logic
- Simplest possible setup

---

## Matcher Configuration

### Understanding Matchers

Matchers determine which routes run middleware.

**Match all routes (except static assets):**
```typescript
export const config = {
  matcher: ["/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)"],
}
```

**Match specific routes:**
```typescript
export const config = {
  matcher: ["/dashboard/:path*", "/admin/:path*", "/api/:path*"],
}
```

**Match all except specific routes:**
```typescript
export const config = {
  matcher: ["/((?!api|about|contact).*)"],
}
```

**Common patterns:**
```typescript
// Match everything
matcher: "/:path*"

// Match /dashboard and all subroutes
matcher: "/dashboard/:path*"

// Match multiple specific routes
matcher: ["/dashboard/:path*", "/admin/:path*", "/settings/:path*"]

// Exclude API routes
matcher: ["/((?!api).*)"]
```

---

## Route Protection Patterns

### Pattern 1: Public + Protected Routes

```typescript
import { auth } from "@/auth"
import { NextResponse } from "next/server"

export default auth((req) => {
  const { pathname } = req.nextUrl
  const isLoggedIn = !!req.auth

  // Public routes (accessible to everyone)
  const publicRoutes = ["/", "/about", "/contact", "/blog"]
  if (publicRoutes.includes(pathname) || pathname.startsWith("/blog/")) {
    return NextResponse.next()
  }

  // Protected routes (require authentication)
  if (!isLoggedIn) {
    const loginUrl = new URL("/login", req.url)
    loginUrl.searchParams.set("callbackUrl", pathname)
    return NextResponse.redirect(loginUrl)
  }

  return NextResponse.next()
})

export const config = {
  matcher: ["/((?!api|_next/static|_next/image|favicon.ico).*)"],
}
```

### Pattern 2: Redirect Logged-In Users

```typescript
export default auth((req) => {
  const { pathname } = req.nextUrl
  const isLoggedIn = !!req.auth

  // Auth pages (redirect if already logged in)
  const authPages = ["/login", "/signup", "/forgot-password"]

  if (isLoggedIn && authPages.includes(pathname)) {
    return NextResponse.redirect(new URL("/dashboard", req.url))
  }

  // Protected routes
  if (!isLoggedIn && pathname.startsWith("/dashboard")) {
    return NextResponse.redirect(new URL("/login", req.url))
  }

  return NextResponse.next()
})
```

### Pattern 3: Callback URL Preservation

```typescript
export default auth((req) => {
  const { pathname } = req.nextUrl
  const isLoggedIn = !!req.auth

  if (pathname.startsWith("/dashboard") && !isLoggedIn) {
    const loginUrl = new URL("/login", req.url)
    // Preserve original URL for redirect after login
    loginUrl.searchParams.set("callbackUrl", pathname)
    return NextResponse.redirect(loginUrl)
  }

  return NextResponse.next()
})
```

**Login page usage:**
```typescript
// app/login/page.tsx
import { signIn } from "@/auth"

export default async function LoginPage({
  searchParams,
}: {
  searchParams: { callbackUrl?: string }
}) {
  return (
    <form
      action={async () => {
        "use server"
        await signIn("github", {
          redirectTo: searchParams.callbackUrl || "/dashboard",
        })
      }}
    >
      <button type="submit">Sign in</button>
    </form>
  )
}
```

---

## Role-Based Access Control (RBAC)

### Pattern 1: Simple Admin Protection

```typescript
import { auth } from "@/auth"
import { NextResponse } from "next/server"

export default auth((req) => {
  const { pathname } = req.nextUrl
  const userRole = req.auth?.user?.role

  // Admin routes
  if (pathname.startsWith("/admin")) {
    if (!req.auth) {
      return NextResponse.redirect(new URL("/login", req.url))
    }

    if (userRole !== "admin") {
      return NextResponse.redirect(new URL("/unauthorized", req.url))
    }
  }

  return NextResponse.next()
})
```

### Pattern 2: Hierarchical Roles

```typescript
enum UserRole {
  GUEST = 0,
  USER = 1,
  MODERATOR = 2,
  ADMIN = 3,
}

function hasPermission(userRole: string, requiredRole: UserRole): boolean {
  const roleValue = UserRole[userRole as keyof typeof UserRole] || 0
  return roleValue >= requiredRole
}

export default auth((req) => {
  const { pathname } = req.nextUrl
  const userRole = req.auth?.user?.role

  // Admin routes - require ADMIN
  if (pathname.startsWith("/admin")) {
    if (!hasPermission(userRole, UserRole.ADMIN)) {
      return NextResponse.redirect(new URL("/unauthorized", req.url))
    }
  }

  // Moderator routes - require MODERATOR or ADMIN
  if (pathname.startsWith("/moderate")) {
    if (!hasPermission(userRole, UserRole.MODERATOR)) {
      return NextResponse.redirect(new URL("/unauthorized", req.url))
    }
  }

  // User routes - require USER, MODERATOR, or ADMIN
  if (pathname.startsWith("/dashboard")) {
    if (!hasPermission(userRole, UserRole.USER)) {
      return NextResponse.redirect(new URL("/login", req.url))
    }
  }

  return NextResponse.next()
})
```

### Pattern 3: Permission-Based Access

```typescript
type Permission = "read" | "write" | "delete" | "admin"

const rolePermissions: Record<string, Permission[]> = {
  admin: ["read", "write", "delete", "admin"],
  moderator: ["read", "write", "delete"],
  user: ["read", "write"],
  guest: ["read"],
}

function hasPermission(userRole: string, permission: Permission): boolean {
  return rolePermissions[userRole]?.includes(permission) ?? false
}

export default auth((req) => {
  const { pathname } = req.nextUrl
  const userRole = req.auth?.user?.role || "guest"

  // Delete routes require delete permission
  if (req.method === "DELETE") {
    if (!hasPermission(userRole, "delete")) {
      return new Response("Forbidden", { status: 403 })
    }
  }

  // Admin panel requires admin permission
  if (pathname.startsWith("/admin")) {
    if (!hasPermission(userRole, "admin")) {
      return NextResponse.redirect(new URL("/unauthorized", req.url))
    }
  }

  return NextResponse.next()
})
```

---

## API Route Protection

### Pattern 1: Protect All API Routes

```typescript
export default auth((req) => {
  const { pathname } = req.nextUrl

  // Allow auth API routes
  if (pathname.startsWith("/api/auth")) {
    return NextResponse.next()
  }

  // Allow public API routes
  const publicApiRoutes = ["/api/health", "/api/public"]
  if (publicApiRoutes.includes(pathname)) {
    return NextResponse.next()
  }

  // Protect all other API routes
  if (pathname.startsWith("/api")) {
    if (!req.auth) {
      return NextResponse.json(
        { error: "Unauthorized" },
        { status: 401 }
      )
    }
  }

  return NextResponse.next()
})
```

### Pattern 2: API Key + Session Auth

```typescript
export default auth((req) => {
  const { pathname } = req.nextUrl

  if (pathname.startsWith("/api")) {
    const apiKey = req.headers.get("x-api-key")
    const isAuthenticated = !!req.auth

    // Allow if either API key or session is valid
    if (!apiKey && !isAuthenticated) {
      return NextResponse.json(
        { error: "Unauthorized - API key or session required" },
        { status: 401 }
      )
    }

    // Validate API key
    if (apiKey && apiKey !== process.env.API_SECRET_KEY) {
      return NextResponse.json(
        { error: "Invalid API key" },
        { status: 401 }
      )
    }
  }

  return NextResponse.next()
})
```

---

## Advanced Patterns

### Pattern 1: Rate Limiting by Role

```typescript
const rateLimits: Record<string, { requests: number; window: number }> = {
  admin: { requests: 1000, window: 60 }, // 1000 requests/min
  user: { requests: 100, window: 60 }, // 100 requests/min
  guest: { requests: 10, window: 60 }, // 10 requests/min
}

// Note: This is a simplified example. Production use Redis or similar.
const requestCounts = new Map<string, { count: number; resetAt: number }>()

export default auth((req) => {
  const userRole = req.auth?.user?.role || "guest"
  const userId = req.auth?.user?.id || req.ip || "anonymous"
  const limit = rateLimits[userRole]

  const now = Date.now()
  const userRequests = requestCounts.get(userId)

  if (!userRequests || userRequests.resetAt < now) {
    requestCounts.set(userId, {
      count: 1,
      resetAt: now + limit.window * 1000,
    })
  } else {
    userRequests.count++

    if (userRequests.count > limit.requests) {
      return NextResponse.json(
        { error: "Rate limit exceeded" },
        { status: 429 }
      )
    }
  }

  return NextResponse.next()
})
```

### Pattern 2: IP Whitelisting (Admin Routes)

```typescript
const ADMIN_IPS = ["192.168.1.1", "10.0.0.1"]

export default auth((req) => {
  const { pathname } = req.nextUrl

  if (pathname.startsWith("/admin")) {
    const clientIp = req.ip || req.headers.get("x-forwarded-for")

    // Check authentication
    if (!req.auth || req.auth.user.role !== "admin") {
      return NextResponse.redirect(new URL("/unauthorized", req.url))
    }

    // Check IP whitelist
    if (!ADMIN_IPS.includes(clientIp)) {
      console.warn(`Blocked admin access from IP: ${clientIp}`)
      return NextResponse.json(
        { error: "Access denied from this IP" },
        { status: 403 }
      )
    }
  }

  return NextResponse.next()
})
```

### Pattern 3: Time-Based Access

```typescript
export default auth((req) => {
  const { pathname } = req.nextUrl

  // Restrict admin panel to business hours (9 AM - 5 PM)
  if (pathname.startsWith("/admin")) {
    const now = new Date()
    const hour = now.getHours()

    if (hour < 9 || hour >= 17) {
      return NextResponse.json(
        { error: "Admin panel only accessible during business hours (9 AM - 5 PM)" },
        { status: 403 }
      )
    }
  }

  return NextResponse.next()
})
```

---

## Debugging Middleware

### Pattern: Log Middleware Execution

```typescript
export default auth((req) => {
  console.log({
    pathname: req.nextUrl.pathname,
    isAuthenticated: !!req.auth,
    userRole: req.auth?.user?.role,
    method: req.method,
  })

  // Your middleware logic...

  return NextResponse.next()
})
```

### Pattern: Test Middleware Locally

```bash
# Test protected route
curl http://localhost:3000/dashboard

# Test with session cookie
curl http://localhost:3000/dashboard \
  -H "Cookie: next-auth.session-token=your-token-here"
```

---

## Common Patterns Summary

| Pattern | Use Case |
|---------|----------|
| **Simple Session Keep-Alive** | Refresh session expiry |
| **Public + Protected Routes** | Basic route protection |
| **Redirect Logged-In Users** | Prevent access to auth pages |
| **Callback URL Preservation** | Return users after login |
| **Simple Admin Protection** | Protect admin routes |
| **Hierarchical Roles** | Multi-level access control |
| **Permission-Based Access** | Granular permissions |
| **Protect All API Routes** | API authentication |
| **API Key + Session Auth** | Multiple auth methods |
| **Rate Limiting by Role** | Prevent abuse |
| **IP Whitelisting** | Restrict by IP address |
| **Time-Based Access** | Business hours restriction |

---

## Best Practices

### ✅ Do:

1. **Use matcher to limit middleware execution**
   - Improves performance
   - Avoids unnecessary processing

2. **Return NextResponse.next() for allowed requests**
   - Continues request processing
   - Allows Next.js to handle rendering

3. **Use NextResponse.redirect() for redirects**
   - Preserves URL structure
   - Works with Next.js routing

4. **Store role in JWT for edge access**
   - Middleware runs in edge runtime
   - Can't query database

5. **Add logging for debugging**
   - Helps troubleshoot issues
   - Track authentication attempts

### ❌ Don't:

1. **Don't query database in middleware**
   - Edge runtime limitation (unless D1/Upstash)
   - Use JWT with role claims instead

2. **Don't use complex logic**
   - Keep middleware fast (<10ms)
   - Move heavy logic to server components

3. **Don't forget matcher config**
   - Without matcher, runs on ALL routes
   - Slows down static assets

4. **Don't block auth routes**
   - Always allow `/api/auth/*`
   - Prevents login/logout from working

5. **Don't use for data fetching**
   - Middleware is for routing logic only
   - Fetch data in server components

---

## Testing Middleware

### Unit Testing

```typescript
// __tests__/middleware.test.ts
import { NextRequest } from "next/server"
import middleware from "@/middleware"

describe("Middleware", () => {
  it("redirects unauthenticated users to login", () => {
    const req = new NextRequest(new URL("http://localhost/dashboard"))
    const res = middleware(req)

    expect(res.status).toBe(307) // Redirect
    expect(res.headers.get("location")).toContain("/login")
  })

  it("allows authenticated users", () => {
    const req = new NextRequest(new URL("http://localhost/dashboard"))
    // Mock auth session
    req.auth = { user: { id: "1", role: "user" } }

    const res = middleware(req)

    expect(res.status).toBe(200)
  })
})
```

---

**For more patterns:**
- Auth.js Middleware Docs: https://authjs.dev/getting-started/session-management/protecting
- Next.js Middleware Docs: https://nextjs.org/docs/app/building-your-application/routing/middleware
