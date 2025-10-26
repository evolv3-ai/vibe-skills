/**
 * Edge-Compatible Auth.js Configuration
 *
 * Use when: Need to use Auth.js in middleware (edge runtime)
 *
 * This config file is edge-compatible (no database adapter).
 * Import this in middleware.ts to avoid edge runtime errors.
 *
 * For full auth config with database, see auth.ts
 */

import type { NextAuthConfig } from "next-auth"
import GitHub from "next-auth/providers/github"
import Google from "next-auth/providers/google"

export default {
  providers: [
    GitHub({
      clientId: process.env.AUTH_GITHUB_ID,
      clientSecret: process.env.AUTH_GITHUB_SECRET,
    }),
    Google({
      clientId: process.env.AUTH_GOOGLE_ID,
      clientSecret: process.env.AUTH_GOOGLE_SECRET,
    }),
  ],

  // Optional: Custom pages
  pages: {
    signIn: "/login",
  },

  // Optional: Callbacks (must be edge-compatible, no database queries)
  callbacks: {
    async authorized({ auth, request: { nextUrl } }) {
      const isLoggedIn = !!auth?.user
      const isOnDashboard = nextUrl.pathname.startsWith("/dashboard")

      if (isOnDashboard) {
        if (isLoggedIn) return true
        return false // Redirect to login page
      } else if (isLoggedIn) {
        return Response.redirect(new URL("/dashboard", nextUrl))
      }

      return true
    },
  },
} satisfies NextAuthConfig
