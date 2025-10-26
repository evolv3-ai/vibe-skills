/**
 * Simple Next.js Auth.js Configuration (JWT Sessions)
 *
 * Use when: Basic OAuth authentication, no database needed
 *
 * Features:
 * - JWT session strategy (no database)
 * - GitHub OAuth provider
 * - Edge-compatible
 *
 * Setup:
 * 1. Copy this file to your project root as `auth.ts`
 * 2. Install dependencies: npm install next-auth@latest
 * 3. Set environment variables in .env.local
 * 4. Create API route handler (see app/api/auth/[...nextauth]/route.ts)
 */

import NextAuth from "next-auth"
import GitHub from "next-auth/providers/github"
import Google from "next-auth/providers/google"

export const { handlers, auth, signIn, signOut } = NextAuth({
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

  // Session configuration
  session: {
    strategy: "jwt", // Use JWT tokens (no database)
    maxAge: 30 * 24 * 60 * 60, // 30 days
  },

  // Optional: Customize session data
  callbacks: {
    async jwt({ token, user }) {
      // Add user ID to JWT on sign in
      if (user) {
        token.id = user.id
      }
      return token
    },

    async session({ session, token }) {
      // Expose user ID to session
      if (session.user) {
        session.user.id = token.id as string
      }
      return session
    },
  },

  // Optional: Custom pages
  pages: {
    signIn: "/login",
    // signOut: "/logout",
    // error: "/error",
  },
})

/**
 * TypeScript augmentation for session types
 */
declare module "next-auth" {
  interface Session {
    user: {
      id: string
    } & DefaultSession["user"]
  }
}

declare module "next-auth/jwt" {
  interface JWT {
    id: string
  }
}
