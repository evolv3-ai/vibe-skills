/**
 * Next.js Middleware with Auth.js
 *
 * Use when: Need session management, route protection, or RBAC
 *
 * Features:
 * - Automatic session refresh
 * - Route protection
 * - Role-based access control
 */

import { auth } from "@/auth"
import { NextResponse } from "next/server"

/**
 * OPTION 1: Simple session keep-alive (no custom logic)
 *
 * Uncomment this to just keep sessions alive:
 */
// export { auth as middleware } from "@/auth"

/**
 * OPTION 2: Custom middleware with route protection
 *
 * Use this for custom logic like route protection or RBAC
 */
export default auth((req) => {
  const { pathname } = req.nextUrl
  const isLoggedIn = !!req.auth

  // Public routes (no auth required)
  const publicRoutes = ["/", "/login", "/signup", "/about"]
  if (publicRoutes.includes(pathname)) {
    return NextResponse.next()
  }

  // Protected routes (auth required)
  if (pathname.startsWith("/dashboard")) {
    if (!isLoggedIn) {
      const loginUrl = new URL("/login", req.url)
      loginUrl.searchParams.set("callbackUrl", pathname)
      return NextResponse.redirect(loginUrl)
    }
  }

  // Admin routes (role-based)
  if (pathname.startsWith("/admin")) {
    if (!isLoggedIn) {
      return NextResponse.redirect(new URL("/login", req.url))
    }

    // Check for admin role (requires custom JWT callback)
    if (req.auth.user.role !== "admin") {
      return NextResponse.redirect(new URL("/unauthorized", req.url))
    }
  }

  // API routes (require auth)
  if (pathname.startsWith("/api")) {
    // Allow public API routes
    if (pathname.startsWith("/api/auth")) {
      return NextResponse.next()
    }

    // Protect all other API routes
    if (!isLoggedIn) {
      return NextResponse.json(
        { error: "Unauthorized" },
        { status: 401 }
      )
    }
  }

  return NextResponse.next()
})

/**
 * Matcher configuration
 *
 * Specify which routes to run middleware on.
 * This example runs on all routes except static files.
 */
export const config = {
  matcher: [
    /*
     * Match all request paths except:
     * - _next/static (static files)
     * - _next/image (image optimization)
     * - favicon.ico (favicon)
     * - public folder files
     */
    "/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)",
  ],
}

/**
 * Alternative matchers:
 */

// Only specific routes
// export const config = {
//   matcher: ["/dashboard/:path*", "/admin/:path*", "/api/:path*"],
// }

// All routes except specific ones
// export const config = {
//   matcher: ["/((?!api|_next/static|_next/image|favicon.ico).*)"],
// }
