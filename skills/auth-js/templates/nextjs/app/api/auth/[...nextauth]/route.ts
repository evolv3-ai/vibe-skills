/**
 * Next.js App Router API Route Handler for Auth.js
 *
 * CRITICAL: This file MUST be at exactly this path:
 * app/api/auth/[...nextauth]/route.ts
 *
 * This creates the following routes:
 * - GET/POST /api/auth/signin
 * - GET/POST /api/auth/signout
 * - GET/POST /api/auth/callback/:provider
 * - GET/POST /api/auth/session
 * - GET/POST /api/auth/csrf
 * - GET/POST /api/auth/providers
 */

import { handlers } from "@/auth"

export const { GET, POST } = handlers
