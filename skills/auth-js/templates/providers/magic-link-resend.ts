/**
 * Magic Link Provider (Passwordless Email Auth)
 *
 * Use when: Implementing passwordless authentication
 *
 * CRITICAL REQUIREMENTS:
 * 1. MUST use a database adapter (PrismaAdapter, D1Adapter, etc.)
 * 2. MUST have verification_tokens table in database
 * 3. MUST configure email provider (Resend, SendGrid, etc.)
 *
 * Features:
 * - Passwordless authentication
 * - Email-based verification
 * - Secure token generation
 * - Custom email templates
 *
 * Setup Resend:
 * 1. Sign up at https://resend.com
 * 2. Get API key
 * 3. Verify your domain (for production)
 * 4. Add AUTH_RESEND_KEY to .env.local
 */

import NextAuth from "next-auth"
import Resend from "next-auth/providers/resend"
import { PrismaAdapter } from "@auth/prisma-adapter"
import { PrismaClient } from "@prisma/client"

const prisma = new PrismaClient()

export const { handlers, auth, signIn, signOut } = NextAuth({
  /**
   * Database adapter
   *
   * CRITICAL: Magic links REQUIRE a database adapter
   */
  adapter: PrismaAdapter(prisma),

  providers: [
    /**
     * Resend Email Provider
     *
     * Sends magic link emails via Resend
     */
    Resend({
      /**
       * API Key
       * Get from: https://resend.com/api-keys
       */
      apiKey: process.env.AUTH_RESEND_KEY,

      /**
       * From email address
       *
       * IMPORTANT: Must be verified in Resend dashboard
       * For development: Use resend's test domain (delivered to your inbox only)
       * For production: Use your verified domain
       */
      from: process.env.AUTH_EMAIL_FROM || "noreply@yourdomain.com",

      /**
       * Optional: Custom email content
       */
      // sendVerificationRequest: async ({ identifier, url, provider }) => {
      //   const { host } = new URL(url)
      //   const result = await resend.emails.send({
      //     from: provider.from,
      //     to: identifier,
      //     subject: `Sign in to ${host}`,
      //     html: `
      //       <h1>Sign in to ${host}</h1>
      //       <p>Click the link below to sign in:</p>
      //       <a href="${url}">Sign in</a>
      //       <p>This link expires in 24 hours.</p>
      //     `,
      //   })
      //   if (result.error) {
      //     throw new Error(result.error.message)
      //   }
      // },
    }),

    /**
     * Alternative: SendGrid
     */
    // import { SendGridProvider } from "next-auth/providers/sendgrid"
    // SendGridProvider({
    //   apiKey: process.env.AUTH_SENDGRID_KEY,
    //   from: "noreply@yourdomain.com",
    // }),

    /**
     * Alternative: Nodemailer (SMTP)
     */
    // import { EmailProvider } from "next-auth/providers/email"
    // EmailProvider({
    //   server: process.env.EMAIL_SERVER, // "smtp://user:pass@smtp.example.com:587"
    //   from: "noreply@yourdomain.com",
    // }),
  ],

  /**
   * Session configuration
   *
   * Can use either JWT or database sessions with magic links
   * Database sessions are more secure (can revoke tokens)
   */
  session: {
    strategy: "database", // Recommended for magic links
    maxAge: 30 * 24 * 60 * 60, // 30 days
    updateAge: 24 * 60 * 60, // Update session in DB every 24 hours
  },

  /**
   * Callbacks
   */
  callbacks: {
    /**
     * Sign-in callback
     *
     * Optional: Add custom logic before sign-in
     */
    async signIn({ user, email }) {
      // Example: Only allow certain email domains
      const allowedDomains = ["company.com", "partner.com"]
      const userEmail = user.email || email?.verificationRequest?.identifier

      if (userEmail) {
        const domain = userEmail.split("@")[1]
        if (!allowedDomains.includes(domain)) {
          return false // Reject sign-in
        }
      }

      return true
    },

    /**
     * Session callback
     *
     * Add custom data to session
     */
    async session({ session, user }) {
      if (session.user) {
        session.user.id = user.id
        // Add any custom user fields from database
        session.user.role = user.role
      }
      return session
    },
  },

  /**
   * Pages configuration
   */
  pages: {
    signIn: "/login",
    verifyRequest: "/auth/verify-request", // Show "Check your email" page
    error: "/auth/error",
  },

  /**
   * Email configuration
   */
  // Optional: Customize verification token expiry
  // verificationTokenExpiry: 24 * 60 * 60, // 24 hours (default)
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

/**
 * Database Schema Requirements
 *
 * Your Prisma schema MUST include the verification_tokens table:
 *
 * model VerificationToken {
 *   identifier String
 *   token      String   @unique
 *   expires    DateTime
 *
 *   @@unique([identifier, token])
 * }
 *
 * For D1 (SQL):
 *
 * CREATE TABLE verification_tokens (
 *   identifier TEXT NOT NULL,
 *   token      TEXT UNIQUE NOT NULL,
 *   expires    INTEGER NOT NULL,
 *   PRIMARY KEY (identifier, token)
 * );
 */

/**
 * Example: Custom verify-request page
 *
 * Create app/auth/verify-request/page.tsx:
 *
 * export default function VerifyRequest() {
 *   return (
 *     <div>
 *       <h1>Check your email</h1>
 *       <p>A sign-in link has been sent to your email address.</p>
 *       <p>Click the link in the email to sign in.</p>
 *     </div>
 *   )
 * }
 */
