#!/bin/bash

# D1 Database Setup Script for Auth.js
# Creates and initializes D1 database with Auth.js tables

set -e # Exit on error

echo "🗄️  Auth.js D1 Database Setup"
echo ""

# Check if wrangler is installed
if ! command -v wrangler &> /dev/null; then
  echo "❌ Error: Wrangler CLI not found"
  echo "   Install with: npm install -g wrangler"
  exit 1
fi

# Get database name
read -p "📝 Enter database name (default: auth_db): " DB_NAME
DB_NAME=${DB_NAME:-auth_db}

echo ""
echo "Creating D1 database: $DB_NAME..."
echo ""

# Create database
CREATE_OUTPUT=$(wrangler d1 create "$DB_NAME" 2>&1)

if [ $? -ne 0 ]; then
  echo "❌ Error creating database:"
  echo "$CREATE_OUTPUT"
  exit 1
fi

echo "$CREATE_OUTPUT"
echo ""

# Extract database ID
DB_ID=$(echo "$CREATE_OUTPUT" | grep -oP 'database_id = "\K[^"]+' || echo "")

if [ -z "$DB_ID" ]; then
  echo "⚠️  Could not extract database ID automatically"
  echo "   Check the output above and copy the database_id manually"
  echo ""
  read -p "Enter database ID: " DB_ID
fi

echo ""
echo "✅ Database created!"
echo "   Name: $DB_NAME"
echo "   ID: $DB_ID"
echo ""

# Ask if user wants to run migrations
read -p "📊 Run Auth.js table migrations? (y/n): " RUN_MIGRATIONS

if [ "$RUN_MIGRATIONS" = "y" ] || [ "$RUN_MIGRATIONS" = "Y" ]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  SCHEMA_FILE="$SCRIPT_DIR/../templates/cloudflare-workers/schema.sql"

  if [ ! -f "$SCHEMA_FILE" ]; then
    echo "❌ Error: schema.sql not found at $SCHEMA_FILE"
    exit 1
  fi

  echo ""
  echo "Running migrations..."
  wrangler d1 execute "$DB_NAME" --file="$SCHEMA_FILE"

  if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Migrations complete!"
    echo "   Tables created: users, accounts, sessions, verification_tokens"
  else
    echo ""
    echo "❌ Migration failed"
    exit 1
  fi
fi

echo ""
echo "📋 Next steps:"
echo ""
echo "1. Add to wrangler.jsonc:"
echo "   {"
echo "     \"d1_databases\": ["
echo "       {"
echo "         \"binding\": \"DB\","
echo "         \"database_name\": \"$DB_NAME\","
echo "         \"database_id\": \"$DB_ID\""
echo "       }"
echo "     ]"
echo "   }"
echo ""
echo "2. Update your Worker code to use D1Adapter:"
echo "   import { D1Adapter } from '@auth/d1-adapter'"
echo "   adapter: D1Adapter(c.env.DB)"
echo ""
echo "3. Set environment variables:"
echo "   npx wrangler secret put AUTH_SECRET"
echo "   npx wrangler secret put AUTH_GITHUB_ID"
echo "   npx wrangler secret put AUTH_GITHUB_SECRET"
echo ""
echo "4. Deploy:"
echo "   npx wrangler deploy"
echo ""
echo "✨ Setup complete!"
