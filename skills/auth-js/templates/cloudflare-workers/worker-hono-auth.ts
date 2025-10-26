/**
 * Cloudflare Workers + Hono + Auth.js + D1 Example
 *
 * Use when: Building authentication in Cloudflare Workers
 *
 * Features:
 * - Hono framework for routing
 * - Auth.js with D1 adapter
 * - OAuth providers (GitHub, Google)
 * - Database sessions
 * - Full edge compatibility
 *
 * Setup:
 * 1. Create D1 database: npx wrangler d1 create auth_db
 * 2. Add database_id to wrangler.jsonc
 * 3. Run migrations: npx wrangler d1 execute auth_db --file=./schema.sql
 * 4. Add environment variables: npx wrangler secret put AUTH_SECRET
 * 5. Deploy: npx wrangler deploy
 */

import { Hono } from 'hono'
import { Auth } from '@auth/core'
import { D1Adapter } from '@auth/d1-adapter'
import GitHub from '@auth/core/providers/github'
import Google from '@auth/core/providers/google'

/**
 * Environment bindings
 */
type Bindings = {
  DB: D1Database
  AUTH_SECRET: string
  AUTH_GITHUB_ID: string
  AUTH_GITHUB_SECRET: string
  AUTH_GOOGLE_ID: string
  AUTH_GOOGLE_SECRET: string
  ENVIRONMENT: string // "development" | "production"
}

const app = new Hono<{ Bindings: Bindings }>()

/**
 * Auth.js routes
 *
 * Handles all authentication routes:
 * - /api/auth/signin
 * - /api/auth/signout
 * - /api/auth/callback/:provider
 * - /api/auth/session
 * - etc.
 */
app.all('/api/auth/*', async (c) => {
  const response = await Auth(c.req.raw, {
    adapter: D1Adapter(c.env.DB),
    providers: [
      GitHub({
        clientId: c.env.AUTH_GITHUB_ID,
        clientSecret: c.env.AUTH_GITHUB_SECRET,
      }),
      Google({
        clientId: c.env.AUTH_GOOGLE_ID,
        clientSecret: c.env.AUTH_GOOGLE_SECRET,
      }),
    ],
    secret: c.env.AUTH_SECRET,
    trustHost: true, // Required for Cloudflare Workers

    // Optional: Custom callbacks
    callbacks: {
      async jwt({ token, user }) {
        if (user) {
          token.id = user.id
        }
        return token
      },
      async session({ session, token }) {
        if (session.user) {
          session.user.id = token.id as string
        }
        return session
      },
    },
  })

  return response
})

/**
 * Get current session
 *
 * Example: GET /api/session
 */
app.get('/api/session', async (c) => {
  const session = await Auth(c.req.raw, {
    adapter: D1Adapter(c.env.DB),
    providers: [],
    secret: c.env.AUTH_SECRET,
  })

  return c.json({ session })
})

/**
 * Protected route example
 *
 * Requires authentication to access
 */
app.get('/dashboard', async (c) => {
  // Get session
  const authResponse = await Auth(c.req.raw, {
    adapter: D1Adapter(c.env.DB),
    providers: [],
    secret: c.env.AUTH_SECRET,
  })

  const session = await authResponse.json()

  if (!session?.user) {
    return c.redirect('/api/auth/signin')
  }

  return c.json({
    message: 'Protected content',
    user: session.user,
  })
})

/**
 * Public routes
 */
app.get('/', (c) => {
  return c.json({
    message: 'Auth.js + Cloudflare Workers + D1',
    routes: {
      auth: '/api/auth/*',
      session: '/api/session',
      dashboard: '/dashboard (protected)',
    },
  })
})

/**
 * CORS middleware (if needed for frontend)
 */
app.use('*', async (c, next) => {
  await next()

  // Only add CORS in development
  if (c.env.ENVIRONMENT === 'development') {
    c.header('Access-Control-Allow-Origin', '*')
    c.header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS')
    c.header('Access-Control-Allow-Headers', 'Content-Type, Authorization')
  }
})

/**
 * Export worker
 */
export default app
