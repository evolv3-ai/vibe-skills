/**
 * Auth.js D1 Database Schema
 *
 * This schema is compatible with the official @auth/d1-adapter.
 *
 * Run migrations:
 * npx wrangler d1 execute auth_db --file=./schema.sql
 *
 * Or run migrations in code (see migrations.ts)
 */

-- Users table
CREATE TABLE IF NOT EXISTS users (
  id TEXT PRIMARY KEY,
  name TEXT,
  email TEXT UNIQUE NOT NULL,
  emailVerified INTEGER,
  image TEXT,
  createdAt INTEGER DEFAULT (strftime('%s', 'now'))
);

-- Accounts table (OAuth providers)
CREATE TABLE IF NOT EXISTS accounts (
  id TEXT PRIMARY KEY,
  userId TEXT NOT NULL,
  type TEXT NOT NULL,
  provider TEXT NOT NULL,
  providerAccountId TEXT NOT NULL,
  refresh_token TEXT,
  access_token TEXT,
  expires_at INTEGER,
  token_type TEXT,
  scope TEXT,
  id_token TEXT,
  session_state TEXT,
  createdAt INTEGER DEFAULT (strftime('%s', 'now')),
  FOREIGN KEY (userId) REFERENCES users(id) ON DELETE CASCADE,
  UNIQUE(provider, providerAccountId)
);

-- Sessions table
CREATE TABLE IF NOT EXISTS sessions (
  id TEXT PRIMARY KEY,
  userId TEXT NOT NULL,
  expires INTEGER NOT NULL,
  sessionToken TEXT UNIQUE NOT NULL,
  createdAt INTEGER DEFAULT (strftime('%s', 'now')),
  FOREIGN KEY (userId) REFERENCES users(id) ON DELETE CASCADE
);

-- Verification tokens table (for magic links)
CREATE TABLE IF NOT EXISTS verification_tokens (
  identifier TEXT NOT NULL,
  token TEXT UNIQUE NOT NULL,
  expires INTEGER NOT NULL,
  PRIMARY KEY (identifier, token)
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_accounts_userId ON accounts(userId);
CREATE INDEX IF NOT EXISTS idx_sessions_userId ON sessions(userId);
CREATE INDEX IF NOT EXISTS idx_sessions_sessionToken ON sessions(sessionToken);
