/**
 * Full Auth.js Configuration with Database Adapter
 *
 * Use when: Need database sessions, magic links, or full adapter features
 *
 * IMPORTANT: Split configuration for edge compatibility
 * - auth.config.ts: Edge-compatible (no database)
 * - auth.ts: Full config with database adapter
 * - middleware.ts: Uses auth.config.ts
 *
 * This pattern allows middleware to run in edge runtime while
 * keeping database adapter for server-side logic.
 */

import NextAuth from "next-auth"
import { PrismaAdapter } from "@auth/prisma-adapter"
import { PrismaClient } from "@prisma/client"
import authConfig from "./auth.config"

const prisma = new PrismaClient()

export const { handlers, auth, signIn, signOut } = NextAuth({
  adapter: PrismaAdapter(prisma),

  /**
   * CRITICAL: Force JWT sessions for edge compatibility
   *
   * Even though we have a database adapter, we use JWT sessions
   * so that middleware (edge runtime) can access session data.
   *
   * If you don't need middleware, you can use "database" strategy.
   */
  session: { strategy: "jwt" },

  // Import edge-compatible config
  ...authConfig,

  /**
   * Callbacks: Add user data to session
   */
  callbacks: {
    async jwt({ token, user }) {
      if (user) {
        token.id = user.id
        token.role = user.role // Custom field from database
      }
      return token
    },

    async session({ session, token }) {
      if (session.user) {
        session.user.id = token.id as string
        session.user.role = token.role as string
      }
      return session
    },

    // Merge with auth.config.ts callbacks if needed
    ...authConfig.callbacks,
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
