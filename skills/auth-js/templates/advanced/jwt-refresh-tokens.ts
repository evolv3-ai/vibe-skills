/**
 * JWT Token Refresh Pattern (OAuth)
 *
 * Use when: Need to refresh OAuth access tokens automatically
 *
 * This pattern implements automatic token refresh for OAuth providers
 * that support refresh tokens (Google, GitHub, etc.)
 *
 * Features:
 * - Automatic token refresh when expired
 * - Error handling for refresh failures
 * - Works with JWT session strategy
 *
 * IMPORTANT: You need to request offline access to get refresh tokens:
 * - Google: access_type: "offline", prompt: "consent"
 * - GitHub: Refresh tokens not supported
 * - Microsoft: scope: "offline_access"
 */

import NextAuth from "next-auth"
import Google from "next-auth/providers/google"
import type { JWT } from "next-auth/jwt"

export const { handlers, auth, signIn, signOut } = NextAuth({
  providers: [
    Google({
      clientId: process.env.AUTH_GOOGLE_ID,
      clientSecret: process.env.AUTH_GOOGLE_SECRET,

      /**
       * CRITICAL: Request offline access and force consent
       *
       * This ensures you get a refresh_token on first sign-in
       */
      authorization: {
        params: {
          prompt: "consent",
          access_type: "offline",
          response_type: "code",
        },
      },
    }),
  ],

  /**
   * Session configuration
   */
  session: {
    strategy: "jwt", // Required for this pattern
  },

  /**
   * Callbacks
   */
  callbacks: {
    /**
     * JWT callback
     *
     * This callback runs on every request and handles token refresh
     */
    async jwt({ token, account, user }) {
      /**
       * First-time sign-in
       *
       * Save access_token, refresh_token, and expiry time
       */
      if (account && user) {
        return {
          ...token,
          access_token: account.access_token,
          expires_at: account.expires_at, // Unix timestamp
          refresh_token: account.refresh_token,
          user,
        }
      }

      /**
       * Subsequent requests
       *
       * Check if token is still valid
       */
      if (Date.now() < (token.expires_at as number) * 1000) {
        // Token still valid, return as is
        return token
      }

      /**
       * Token expired
       *
       * Try to refresh it using the refresh_token
       */
      return await refreshAccessToken(token)
    },

    /**
     * Session callback
     *
     * Expose access_token and errors to the session
     */
    async session({ session, token }) {
      session.user.id = token.sub as string
      session.accessToken = token.access_token as string
      session.error = token.error as string | undefined

      return session
    },
  },
})

/**
 * Refresh access token using refresh_token
 *
 * Google OAuth 2.0 token endpoint
 */
async function refreshAccessToken(token: JWT): Promise<JWT> {
  try {
    /**
     * Google token endpoint
     *
     * Find other providers' endpoints at:
     * - Microsoft: https://login.microsoftonline.com/{tenant}/oauth2/v2.0/token
     * - GitHub: Not supported
     * - Facebook: https://graph.facebook.com/oauth/access_token
     */
    const url = "https://oauth2.googleapis.com/token"

    const response = await fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: new URLSearchParams({
        client_id: process.env.AUTH_GOOGLE_ID!,
        client_secret: process.env.AUTH_GOOGLE_SECRET!,
        grant_type: "refresh_token",
        refresh_token: token.refresh_token as string,
      }),
    })

    const refreshedTokens = await response.json()

    if (!response.ok) {
      throw refreshedTokens
    }

    /**
     * Return updated token
     *
     * IMPORTANT: Some providers only issue refresh_token once,
     * so preserve the existing one if a new one isn't provided
     */
    return {
      ...token,
      access_token: refreshedTokens.access_token,
      expires_at: Math.floor(Date.now() / 1000 + refreshedTokens.expires_in),
      refresh_token: refreshedTokens.refresh_token ?? token.refresh_token,
    }
  } catch (error) {
    console.error("Error refreshing access token:", error)

    /**
     * Return token with error
     *
     * The error will be exposed to the session, allowing
     * the client to handle it (e.g., force re-authentication)
     */
    return {
      ...token,
      error: "RefreshAccessTokenError",
    }
  }
}

/**
 * TypeScript augmentation
 */
declare module "next-auth" {
  interface Session {
    user: {
      id: string
    } & DefaultSession["user"]
    accessToken: string
    error?: string
  }
}

declare module "next-auth/jwt" {
  interface JWT {
    access_token: string
    expires_at: number
    refresh_token: string
    error?: string
  }
}

/**
 * Client-side error handling
 *
 * In your React components, check for the error:
 *
 * "use client"
 * import { useSession, signIn } from "next-auth/react"
 * import { useEffect } from "react"
 *
 * export default function Component() {
 *   const { data: session } = useSession()
 *
 *   useEffect(() => {
 *     if (session?.error === "RefreshAccessTokenError") {
 *       // Force sign-in to refresh tokens
 *       signIn("google")
 *     }
 *   }, [session])
 *
 *   return <div>...</div>
 * }
 */

/**
 * Database Session Strategy Alternative
 *
 * If using database sessions, you can store tokens in the database:
 *
 * async jwt({ token, account }) {
 *   if (account) {
 *     await prisma.account.update({
 *       where: {
 *         provider_providerAccountId: {
 *           provider: account.provider,
 *           providerAccountId: account.providerAccountId,
 *         },
 *       },
 *       data: {
 *         access_token: account.access_token,
 *         expires_at: account.expires_at,
 *         refresh_token: account.refresh_token,
 *       },
 *     })
 *   }
 *   return token
 * }
 *
 * async session({ session, user }) {
 *   const account = await prisma.account.findFirst({
 *     where: { userId: user.id, provider: "google" },
 *   })
 *
 *   if (account && account.expires_at * 1000 < Date.now()) {
 *     // Refresh token and update database
 *     const newTokens = await refreshAccessToken(account)
 *     await prisma.account.update({
 *       where: { id: account.id },
 *       data: newTokens,
 *     })
 *   }
 *
 *   return session
 * }
 */
