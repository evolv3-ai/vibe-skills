/**
 * Role-Based Access Control (RBAC) with Auth.js
 *
 * Use when: Need to restrict access based on user roles
 *
 * Features:
 * - Custom user roles (admin, user, moderator, etc.)
 * - Role stored in database
 * - Role exposed to JWT and session
 * - Middleware-level route protection
 * - Component-level role checks
 *
 * Setup:
 * 1. Add role field to User model in database
 * 2. Configure JWT callback to add role to token
 * 3. Configure session callback to expose role
 * 4. Use role in middleware or components
 */

import NextAuth from "next-auth"
import { PrismaAdapter } from "@auth/prisma-adapter"
import { PrismaClient } from "@prisma/client"
import Google from "next-auth/providers/google"

const prisma = new PrismaClient()

/**
 * Available user roles
 */
export enum UserRole {
  ADMIN = "admin",
  MODERATOR = "moderator",
  USER = "user",
  GUEST = "guest",
}

export const { handlers, auth, signIn, signOut } = NextAuth({
  adapter: PrismaAdapter(prisma),

  providers: [
    Google({
      clientId: process.env.AUTH_GOOGLE_ID,
      clientSecret: process.env.AUTH_GOOGLE_SECRET,

      /**
       * Profile callback
       *
       * Map OAuth profile to user data, including role
       */
      profile(profile) {
        return {
          id: profile.sub,
          name: profile.name,
          email: profile.email,
          image: profile.picture,
          /**
           * Default role for new users
           *
           * You can customize this based on email domain, etc.
           */
          role: profile.email?.endsWith("@admin.com")
            ? UserRole.ADMIN
            : UserRole.USER,
        }
      },
    }),
  ],

  /**
   * Session configuration
   *
   * Using JWT for edge compatibility (required for middleware)
   */
  session: {
    strategy: "jwt",
  },

  /**
   * Callbacks
   */
  callbacks: {
    /**
     * JWT callback
     *
     * Add role to JWT token from user or database
     */
    async jwt({ token, user, trigger, session }) {
      /**
       * On sign-in, add role from user object
       */
      if (user) {
        token.role = user.role
        token.id = user.id
      }

      /**
       * On session update (from client), refresh role from database
       *
       * This handles role changes while user is signed in
       */
      if (trigger === "update") {
        const dbUser = await prisma.user.findUnique({
          where: { id: token.sub },
          select: { role: true },
        })

        if (dbUser) {
          token.role = dbUser.role
        }
      }

      return token
    },

    /**
     * Session callback
     *
     * Expose role to session (client-side)
     */
    async session({ session, token }) {
      if (session.user) {
        session.user.id = token.sub as string
        session.user.role = token.role as UserRole
      }
      return session
    },

    /**
     * Sign-in callback
     *
     * Optional: Restrict sign-in based on role
     */
    async signIn({ user }) {
      // Example: Only allow admins and users (block guests)
      if (user.role === UserRole.GUEST) {
        return false
      }
      return true
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
      role: UserRole
    } & DefaultSession["user"]
  }

  interface User {
    role: UserRole
  }
}

declare module "next-auth/jwt" {
  interface JWT {
    role: UserRole
  }
}

/**
 * Prisma Schema
 *
 * Add this to your schema.prisma:
 *
 * enum UserRole {
 *   ADMIN
 *   MODERATOR
 *   USER
 *   GUEST
 * }
 *
 * model User {
 *   id            String    @id @default(cuid())
 *   name          String?
 *   email         String    @unique
 *   emailVerified DateTime?
 *   image         String?
 *   role          UserRole  @default(USER)
 *   accounts      Account[]
 *   sessions      Session[]
 * }
 */

/**
 * Middleware Example
 *
 * Protect routes based on role:
 *
 * // middleware.ts
 * import { auth } from "@/auth"
 * import { UserRole } from "@/auth"
 * import { NextResponse } from "next/server"
 *
 * export default auth((req) => {
 *   const { pathname } = req.nextUrl
 *   const userRole = req.auth?.user?.role
 *
 *   // Admin routes - require ADMIN role
 *   if (pathname.startsWith("/admin")) {
 *     if (userRole !== UserRole.ADMIN) {
 *       return NextResponse.redirect(new URL("/unauthorized", req.url))
 *     }
 *   }
 *
 *   // Moderator routes - require MODERATOR or ADMIN
 *   if (pathname.startsWith("/moderate")) {
 *     if (![UserRole.ADMIN, UserRole.MODERATOR].includes(userRole)) {
 *       return NextResponse.redirect(new URL("/unauthorized", req.url))
 *     }
 *   }
 *
 *   // Protected routes - require any authenticated user
 *   if (pathname.startsWith("/dashboard")) {
 *     if (!req.auth) {
 *       return NextResponse.redirect(new URL("/login", req.url))
 *     }
 *   }
 *
 *   return NextResponse.next()
 * })
 */

/**
 * Component-Level Role Check
 *
 * Server Component:
 *
 * import { auth } from "@/auth"
 * import { UserRole } from "@/auth"
 *
 * export default async function AdminPanel() {
 *   const session = await auth()
 *
 *   if (session?.user?.role !== UserRole.ADMIN) {
 *     return <div>Access denied</div>
 *   }
 *
 *   return <div>Admin panel content</div>
 * }
 *
 * Client Component:
 *
 * "use client"
 * import { useSession } from "next-auth/react"
 * import { UserRole } from "@/auth"
 *
 * export default function AdminPanel() {
 *   const { data: session } = useSession()
 *
 *   if (session?.user?.role !== UserRole.ADMIN) {
 *     return <div>Access denied</div>
 *   }
 *
 *   return <div>Admin panel content</div>
 * }
 */

/**
 * Helper Functions
 */

/**
 * Check if user has required role
 */
export function hasRole(userRole: UserRole, requiredRole: UserRole): boolean {
  const roleHierarchy = {
    [UserRole.GUEST]: 0,
    [UserRole.USER]: 1,
    [UserRole.MODERATOR]: 2,
    [UserRole.ADMIN]: 3,
  }

  return roleHierarchy[userRole] >= roleHierarchy[requiredRole]
}

/**
 * Update user role (admin function)
 */
export async function updateUserRole(userId: string, newRole: UserRole) {
  return await prisma.user.update({
    where: { id: userId },
    data: { role: newRole },
  })
}

/**
 * Get all users by role
 */
export async function getUsersByRole(role: UserRole) {
  return await prisma.user.findMany({
    where: { role },
    select: {
      id: true,
      name: true,
      email: true,
      role: true,
    },
  })
}
