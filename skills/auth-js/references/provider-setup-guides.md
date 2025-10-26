# OAuth Provider Setup Guides

**Last Updated**: 2025-10-26
**Auth.js Version**: v5 (next-auth 4.24+)

Step-by-step guides for setting up OAuth providers with Auth.js.

---

## GitHub OAuth

### Step 1: Create OAuth App

1. Go to https://github.com/settings/developers
2. Click **"New OAuth App"**
3. Fill in details:
   - **Application name**: Your App Name
   - **Homepage URL**: `http://localhost:3000` (development)
   - **Authorization callback URL**: `http://localhost:3000/api/auth/callback/github`
4. Click **"Register application"**
5. Click **"Generate a new client secret"**
6. Copy **Client ID** and **Client Secret**

### Step 2: Add Environment Variables

```bash
# .env.local
AUTH_GITHUB_ID=your_github_client_id
AUTH_GITHUB_SECRET=your_github_client_secret
```

### Step 3: Configure Auth.js

```typescript
import GitHub from "next-auth/providers/github"

export const { handlers, auth } = NextAuth({
  providers: [
    GitHub({
      clientId: process.env.AUTH_GITHUB_ID,
      clientSecret: process.env.AUTH_GITHUB_SECRET,
    }),
  ],
})
```

### Production Setup

1. Create new OAuth app for production
2. Set callback URL: `https://yourdomain.com/api/auth/callback/github`
3. Add production credentials to hosting provider
4. **Never commit secrets to git!**

---

## Google OAuth

### Step 1: Create OAuth Client

1. Go to https://console.cloud.google.com/apis/credentials
2. Create new project (or select existing)
3. Click **"Create Credentials"** → **"OAuth client ID"**
4. Configure consent screen (if first time):
   - User type: **External**
   - App name: Your App Name
   - User support email: your@email.com
   - Developer contact: your@email.com
5. Create OAuth client ID:
   - Application type: **Web application**
   - Name: Your App Name
   - Authorized redirect URIs:
     - `http://localhost:3000/api/auth/callback/google` (dev)
     - `https://yourdomain.com/api/auth/callback/google` (prod)
6. Copy **Client ID** and **Client Secret**

### Step 2: Add Environment Variables

```bash
# .env.local
AUTH_GOOGLE_ID=your_google_client_id
AUTH_GOOGLE_SECRET=your_google_client_secret
```

### Step 3: Configure Auth.js

**Basic setup:**

```typescript
import Google from "next-auth/providers/google"

export const { handlers, auth } = NextAuth({
  providers: [
    Google({
      clientId: process.env.AUTH_GOOGLE_ID,
      clientSecret: process.env.AUTH_GOOGLE_SECRET,
    }),
  ],
})
```

**With token refresh (recommended):**

```typescript
import Google from "next-auth/providers/google"

export const { handlers, auth } = NextAuth({
  providers: [
    Google({
      clientId: process.env.AUTH_GOOGLE_ID,
      clientSecret: process.env.AUTH_GOOGLE_SECRET,
      authorization: {
        params: {
          prompt: "consent",
          access_type: "offline",
          response_type: "code",
        },
      },
    }),
  ],
})
```

### Scopes

**Default scopes:** `openid`, `email`, `profile`

**Add more scopes:**

```typescript
Google({
  authorization: {
    params: {
      scope: "openid email profile https://www.googleapis.com/auth/calendar",
    },
  },
})
```

**Common scopes:**
- `https://www.googleapis.com/auth/userinfo.profile` - User profile
- `https://www.googleapis.com/auth/userinfo.email` - Email address
- `https://www.googleapis.com/auth/calendar` - Google Calendar
- `https://www.googleapis.com/auth/drive` - Google Drive

---

## Discord OAuth

### Step 1: Create Discord App

1. Go to https://discord.com/developers/applications
2. Click **"New Application"**
3. Enter application name → Click **"Create"**
4. Go to **"OAuth2"** → **"General"**
5. Add redirect URLs:
   - `http://localhost:3000/api/auth/callback/discord`
   - `https://yourdomain.com/api/auth/callback/discord`
6. Copy **Client ID** and **Client Secret**

### Step 2: Configure Auth.js

```bash
# .env.local
AUTH_DISCORD_ID=your_discord_client_id
AUTH_DISCORD_SECRET=your_discord_client_secret
```

```typescript
import Discord from "next-auth/providers/discord"

export const { handlers, auth } = NextAuth({
  providers: [
    Discord({
      clientId: process.env.AUTH_DISCORD_ID,
      clientSecret: process.env.AUTH_DISCORD_SECRET,
    }),
  ],
})
```

### Scopes

**Default:** `identify`, `email`

**Add guilds (servers):**

```typescript
Discord({
  authorization: {
    params: {
      scope: "identify email guilds",
    },
  },
})
```

---

## Twitter (X) OAuth

### Step 1: Create Twitter App

1. Go to https://developer.twitter.com/en/portal/dashboard
2. Sign up for developer account (if needed)
3. Create new app → Click **"Create Project"**
4. Go to **"Settings"** → **"OAuth 2.0 Settings"**
5. Enable OAuth 2.0
6. Add callback URL: `http://localhost:3000/api/auth/callback/twitter`
7. Copy **Client ID** and **Client Secret**

### Step 2: Configure Auth.js

```bash
# .env.local
AUTH_TWITTER_ID=your_twitter_client_id
AUTH_TWITTER_SECRET=your_twitter_client_secret
```

```typescript
import Twitter from "next-auth/providers/twitter"

export const { handlers, auth } = NextAuth({
  providers: [
    Twitter({
      clientId: process.env.AUTH_TWITTER_ID,
      clientSecret: process.env.AUTH_TWITTER_SECRET,
      version: "2.0", // Use OAuth 2.0
    }),
  ],
})
```

---

## Microsoft (Azure AD) OAuth

### Step 1: Create Azure AD App

1. Go to https://portal.azure.com
2. Navigate to **Azure Active Directory** → **App registrations**
3. Click **"New registration"**
4. Fill in:
   - Name: Your App Name
   - Supported account types: Accounts in any organizational directory and personal Microsoft accounts
   - Redirect URI: `http://localhost:3000/api/auth/callback/azure-ad`
5. Click **"Register"**
6. Copy **Application (client) ID**
7. Go to **"Certificates & secrets"** → **"New client secret"**
8. Copy secret **Value**

### Step 2: Configure Auth.js

```bash
# .env.local
AUTH_AZURE_AD_ID=your_azure_client_id
AUTH_AZURE_AD_SECRET=your_azure_client_secret
AUTH_AZURE_AD_TENANT_ID=common # or your tenant ID
```

```typescript
import AzureAD from "next-auth/providers/azure-ad"

export const { handlers, auth } = NextAuth({
  providers: [
    AzureAD({
      clientId: process.env.AUTH_AZURE_AD_ID,
      clientSecret: process.env.AUTH_AZURE_AD_SECRET,
      tenantId: process.env.AUTH_AZURE_AD_TENANT_ID,
    }),
  ],
})
```

---

## Facebook OAuth

### Step 1: Create Facebook App

1. Go to https://developers.facebook.com/apps
2. Click **"Create App"** → Select **"Consumer"**
3. Enter app name → Click **"Create App"**
4. Go to **"Settings"** → **"Basic"**
5. Copy **App ID** and **App Secret**
6. Add **Facebook Login** product
7. Go to **"Facebook Login"** → **"Settings"**
8. Add redirect URLs:
   - `http://localhost:3000/api/auth/callback/facebook`
   - `https://yourdomain.com/api/auth/callback/facebook`

### Step 2: Configure Auth.js

```bash
# .env.local
AUTH_FACEBOOK_ID=your_facebook_app_id
AUTH_FACEBOOK_SECRET=your_facebook_app_secret
```

```typescript
import Facebook from "next-auth/providers/facebook"

export const { handlers, auth } = NextAuth({
  providers: [
    Facebook({
      clientId: process.env.AUTH_FACEBOOK_ID,
      clientSecret: process.env.AUTH_FACEBOOK_SECRET,
    }),
  ],
})
```

---

## Apple OAuth

### Step 1: Create Apple App ID

1. Go to https://developer.apple.com/account/resources/identifiers/list
2. Click **"+"** → **"App IDs"** → **"Continue"**
3. Select **"App"** → **"Continue"**
4. Fill in:
   - Description: Your App Name
   - Bundle ID: com.yourcompany.yourapp
5. Enable **"Sign in with Apple"**
6. Configure:
   - Primary App ID: (select your app)
   - Domains: yourdomain.com
   - Return URLs: `https://yourdomain.com/api/auth/callback/apple`
7. Create **Service ID**
8. Copy **Service ID** (used as client ID)

### Step 2: Create Private Key

1. Go to **"Keys"** → **"+"**
2. Enable **"Sign in with Apple"**
3. Download **.p8 file**
4. Copy **Key ID**

### Step 3: Configure Auth.js

```bash
# .env.local
AUTH_APPLE_ID=your_service_id
AUTH_APPLE_TEAM_ID=your_team_id
AUTH_APPLE_KEY_ID=your_key_id
AUTH_APPLE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----"
```

```typescript
import Apple from "next-auth/providers/apple"

export const { handlers, auth } = NextAuth({
  providers: [
    Apple({
      clientId: process.env.AUTH_APPLE_ID,
      clientSecret: {
        appleId: process.env.AUTH_APPLE_ID,
        teamId: process.env.AUTH_APPLE_TEAM_ID,
        privateKey: process.env.AUTH_APPLE_PRIVATE_KEY,
        keyId: process.env.AUTH_APPLE_KEY_ID,
      },
    }),
  ],
})
```

---

## Common Setup Issues

### Issue 1: Redirect URI Mismatch

**Error:** `redirect_uri_mismatch`

**Cause:** Callback URL doesn't match provider configuration

**Fix:**
- Check provider dashboard callback URL
- Must match exactly: `http://localhost:3000/api/auth/callback/github`
- Include protocol (http/https)
- No trailing slash

### Issue 2: Invalid Client

**Error:** `invalid_client`

**Cause:**
- Wrong client ID/secret
- Credentials not set in environment

**Fix:**
- Verify environment variables
- Restart dev server after adding env vars
- Check for typos in .env.local

### Issue 3: Scope Not Granted

**Error:** `access_denied`, `insufficient_scope`

**Cause:**
- Requested scope not approved
- User declined permission

**Fix:**
- Check consent screen configuration
- Request fewer scopes initially
- Implement incremental authorization

---

## Multi-Provider Setup

```typescript
import GitHub from "next-auth/providers/github"
import Google from "next-auth/providers/google"
import Discord from "next-auth/providers/discord"

export const { handlers, auth } = NextAuth({
  providers: [
    GitHub({
      clientId: process.env.AUTH_GITHUB_ID,
      clientSecret: process.env.AUTH_GITHUB_SECRET,
    }),
    Google({
      clientId: process.env.AUTH_GOOGLE_ID,
      clientSecret: process.env.AUTH_GOOGLE_SECRET,
    }),
    Discord({
      clientId: process.env.AUTH_DISCORD_ID,
      clientSecret: process.env.AUTH_DISCORD_SECRET,
    }),
  ],
})
```

**Sign in page:**

```typescript
import { signIn } from "@/auth"

export default function SignIn() {
  return (
    <div>
      <form action={async () => {
        "use server"
        await signIn("github")
      }}>
        <button>Sign in with GitHub</button>
      </form>

      <form action={async () => {
        "use server"
        await signIn("google")
      }}>
        <button>Sign in with Google</button>
      </form>

      <form action={async () => {
        "use server"
        await signIn("discord")
      }}>
        <button>Sign in with Discord</button>
      </form>
    </div>
  )
}
```

---

## Environment Variables Template

```bash
# .env.example

# Auth.js
AUTH_SECRET=generate-with-npx-auth-secret

# GitHub
AUTH_GITHUB_ID=your_github_client_id
AUTH_GITHUB_SECRET=your_github_client_secret

# Google
AUTH_GOOGLE_ID=your_google_client_id
AUTH_GOOGLE_SECRET=your_google_client_secret

# Discord
AUTH_DISCORD_ID=your_discord_client_id
AUTH_DISCORD_SECRET=your_discord_client_secret

# Twitter
AUTH_TWITTER_ID=your_twitter_client_id
AUTH_TWITTER_SECRET=your_twitter_client_secret

# Microsoft
AUTH_AZURE_AD_ID=your_azure_client_id
AUTH_AZURE_AD_SECRET=your_azure_client_secret
AUTH_AZURE_AD_TENANT_ID=common

# Facebook
AUTH_FACEBOOK_ID=your_facebook_app_id
AUTH_FACEBOOK_SECRET=your_facebook_app_secret

# Apple
AUTH_APPLE_ID=your_service_id
AUTH_APPLE_TEAM_ID=your_team_id
AUTH_APPLE_KEY_ID=your_key_id
AUTH_APPLE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----"
```

---

**For complete provider list:**
- All Providers: https://authjs.dev/getting-started/providers/oauth
