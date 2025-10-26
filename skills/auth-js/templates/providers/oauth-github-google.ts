/**
 * OAuth Providers (GitHub, Google)
 *
 * Use when: Implementing social login
 *
 * Features:
 * - GitHub OAuth
 * - Google OAuth with offline access (refresh tokens)
 * - Custom profile mapping
 * - Sign-in restrictions (email domain whitelist)
 *
 * Setup GitHub OAuth App:
 * 1. Go to https://github.com/settings/developers
 * 2. Click "New OAuth App"
 * 3. Set callback URL: http://localhost:3000/api/auth/callback/github
 * 4. Copy Client ID and Client Secret to .env.local
 *
 * Setup Google OAuth:
 * 1. Go to https://console.cloud.google.com/apis/credentials
 * 2. Create OAuth 2.0 Client ID
 * 3. Set callback URL: http://localhost:3000/api/auth/callback/google
 * 4. Copy Client ID and Client Secret to .env.local
 */

import NextAuth from "next-auth"
import GitHub from "next-auth/providers/github"
import Google from "next-auth/providers/google"

export const { handlers, auth, signIn, signOut } = NextAuth({
  providers: [
    /**
     * GitHub Provider
     *
     * Default scopes: read:user, user:email
     * Customize scopes if needed (e.g., repo access)
     */
    GitHub({
      clientId: process.env.AUTH_GITHUB_ID,
      clientSecret: process.env.AUTH_GITHUB_SECRET,

      // Optional: Request additional scopes
      // authorization: {
      //   params: {
      //     scope: "read:user user:email repo",
      //   },
      // },

      // Optional: Custom profile mapping
      profile(profile) {
        return {
          id: profile.id.toString(),
          name: profile.name || profile.login,
          email: profile.email,
          image: profile.avatar_url,
          // Add custom fields from GitHub profile
          username: profile.login,
          bio: profile.bio,
        }
      },
    }),

    /**
     * Google Provider
     *
     * IMPORTANT: For token refresh, you need:
     * - access_type: "offline"
     * - prompt: "consent"
     *
     * This ensures you get a refresh_token on first sign-in
     */
    Google({
      clientId: process.env.AUTH_GOOGLE_ID,
      clientSecret: process.env.AUTH_GOOGLE_SECRET,

      /**
       * Authorization params for refresh tokens
       *
       * CRITICAL: These params are required to get refresh_token
       */
      authorization: {
        params: {
          prompt: "consent", // Force consent screen (ensures refresh_token)
          access_type: "offline", // Request offline access
          response_type: "code",
        },
      },

      // Optional: Custom profile mapping
      profile(profile) {
        return {
          id: profile.sub,
          name: profile.name,
          email: profile.email,
          image: profile.picture,
          emailVerified: profile.email_verified,
        }
      },
    }),

    /**
     * More providers (examples):
     */
    // Discord({
    //   clientId: process.env.AUTH_DISCORD_ID,
    //   clientSecret: process.env.AUTH_DISCORD_SECRET,
    // }),
    // Twitter({
    //   clientId: process.env.AUTH_TWITTER_ID,
    //   clientSecret: process.env.AUTH_TWITTER_SECRET,
    //   version: "2.0", // Use OAuth 2.0
    // }),
  ],

  /**
   * Callbacks for custom logic
   */
  callbacks: {
    /**
     * Sign-in callback
     *
     * Use to restrict sign-ins (e.g., email domain whitelist)
     */
    async signIn({ account, profile }) {
      // Example: Only allow company email for Google sign-ins
      if (account?.provider === "google") {
        return profile?.email?.endsWith("@company.com") ?? false
      }

      // Example: Only allow verified emails
      if (account?.provider === "google") {
        return profile?.email_verified === true
      }

      // Allow all other providers
      return true
    },

    /**
     * JWT callback
     *
     * Add custom data to JWT token
     */
    async jwt({ token, account, profile }) {
      // On first sign-in, add OAuth account data
      if (account) {
        token.accessToken = account.access_token
        token.refreshToken = account.refresh_token
        token.provider = account.provider
      }

      // Add profile data
      if (profile) {
        token.username = profile.login || profile.email?.split("@")[0]
      }

      return token
    },

    /**
     * Session callback
     *
     * Expose custom data to session
     */
    async session({ session, token }) {
      session.user.id = token.sub as string
      session.user.username = token.username as string
      session.accessToken = token.accessToken as string

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
      username: string
    } & DefaultSession["user"]
    accessToken: string
  }

  interface Profile {
    login?: string
    avatar_url?: string
    bio?: string
    email_verified?: boolean
  }
}

declare module "next-auth/jwt" {
  interface JWT {
    accessToken?: string
    refreshToken?: string
    provider?: string
    username?: string
  }
}
