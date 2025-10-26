/**
 * Credentials Provider (Email/Password)
 *
 * Use when: Implementing email/password authentication
 *
 * CRITICAL RULES:
 * 1. NEVER throw errors in authorize() - always return null
 * 2. Credentials provider ONLY works with JWT sessions
 * 3. Hash passwords with bcrypt (never store plain text)
 * 4. Validate with Zod before checking credentials
 *
 * ⚠️ Security Considerations:
 * - This example uses bcrypt for password hashing
 * - Rate limiting is recommended (not shown here)
 * - HTTPS is required in production
 * - Consider adding 2FA for sensitive applications
 */

import NextAuth from "next-auth"
import Credentials from "next-auth/providers/credentials"
import { z } from "zod"
import bcrypt from "bcryptjs"
import { db } from "@/lib/db" // Your database client

/**
 * Validation schema
 */
const signInSchema = z.object({
  email: z.string().email({ message: "Invalid email address" }),
  password: z.string().min(8, { message: "Password must be at least 8 characters" }),
})

export const { handlers, auth, signIn, signOut } = NextAuth({
  providers: [
    Credentials({
      /**
       * Credentials configuration
       */
      name: "Credentials",
      credentials: {
        email: {
          label: "Email",
          type: "email",
          placeholder: "you@example.com",
        },
        password: {
          label: "Password",
          type: "password",
        },
      },

      /**
       * Authorize callback
       *
       * CRITICAL: NEVER throw errors - always return null
       * Why? Throwing causes CallbackRouteError instead of CredentialsSignin
       */
      authorize: async (credentials) => {
        try {
          // 1. Validate input with Zod
          const { email, password } = await signInSchema.parseAsync(credentials)

          // 2. Fetch user from database
          const user = await db.user.findUnique({
            where: { email },
            select: {
              id: true,
              email: true,
              name: true,
              image: true,
              password: true, // Hashed password
              role: true,
              emailVerified: true,
            },
          })

          // 3. Check if user exists and has password
          if (!user || !user.password) {
            console.log("User not found or no password set")
            return null // CRITICAL: Return null, DON'T throw
          }

          // 4. Verify password
          const passwordMatch = await bcrypt.compare(password, user.password)

          if (!passwordMatch) {
            console.log("Invalid password")
            return null // CRITICAL: Return null, DON'T throw
          }

          // 5. Optional: Check if email is verified
          if (!user.emailVerified) {
            console.log("Email not verified")
            return null // Or allow sign-in with warning
          }

          // 6. Return user object (DON'T include password!)
          return {
            id: user.id,
            email: user.email,
            name: user.name,
            image: user.image,
            role: user.role,
          }
        } catch (error) {
          // CRITICAL: Return null on error, DON'T throw
          if (error instanceof z.ZodError) {
            console.log("Validation error:", error.errors)
          } else {
            console.error("Auth error:", error)
          }
          return null
        }
      },
    }),
  ],

  /**
   * Session configuration
   *
   * CRITICAL: Credentials provider ONLY works with JWT sessions
   */
  session: {
    strategy: "jwt", // REQUIRED for Credentials provider
    maxAge: 30 * 24 * 60 * 60, // 30 days
  },

  /**
   * Callbacks
   */
  callbacks: {
    /**
     * JWT callback
     *
     * Add custom claims to JWT token
     */
    async jwt({ token, user }) {
      // On sign-in, add user data to token
      if (user) {
        token.id = user.id
        token.role = user.role
      }
      return token
    },

    /**
     * Session callback
     *
     * Expose custom claims to session
     */
    async session({ session, token }) {
      if (session.user) {
        session.user.id = token.id as string
        session.user.role = token.role as string
      }
      return session
    },
  },

  /**
   * Pages configuration
   */
  pages: {
    signIn: "/login", // Custom login page
    // error: "/auth/error", // Custom error page
  },
})

/**
 * Helper: Hash password for new user registration
 *
 * Usage:
 * const hashedPassword = await hashPassword("user-password")
 * await db.user.create({ data: { email, password: hashedPassword } })
 */
export async function hashPassword(password: string): Promise<string> {
  const saltRounds = 10
  return bcrypt.hash(password, saltRounds)
}

/**
 * Helper: Sign-up function (example)
 *
 * This is NOT part of Auth.js - you implement this yourself
 */
export async function signUpUser(email: string, password: string, name: string) {
  // Validate input
  const schema = z.object({
    email: z.string().email(),
    password: z.string().min(8),
    name: z.string().min(2),
  })

  const validated = schema.parse({ email, password, name })

  // Check if user already exists
  const existingUser = await db.user.findUnique({
    where: { email: validated.email },
  })

  if (existingUser) {
    throw new Error("User already exists")
  }

  // Hash password
  const hashedPassword = await hashPassword(validated.password)

  // Create user
  const user = await db.user.create({
    data: {
      email: validated.email,
      password: hashedPassword,
      name: validated.name,
      role: "user",
    },
  })

  return user
}

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
