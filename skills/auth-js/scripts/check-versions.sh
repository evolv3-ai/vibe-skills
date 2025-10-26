#!/bin/bash

# Auth.js Package Version Checker
# Verifies that documented package versions are current

echo "🔍 Checking Auth.js package versions..."
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Package versions from skill documentation
DOCUMENTED_NEXTAUTH="4.24.11"
DOCUMENTED_AUTH_CORE="0.41.1"
DOCUMENTED_D1_ADAPTER="1.11.1"

# Check next-auth
echo "📦 Checking next-auth..."
LATEST_NEXTAUTH=$(npm view next-auth version 2>/dev/null)

if [ -z "$LATEST_NEXTAUTH" ]; then
  echo -e "${RED}❌ Error: Could not fetch next-auth version${NC}"
else
  if [ "$LATEST_NEXTAUTH" = "$DOCUMENTED_NEXTAUTH" ]; then
    echo -e "${GREEN}✅ next-auth: $DOCUMENTED_NEXTAUTH (current)${NC}"
  else
    echo -e "${YELLOW}⚠️  next-auth: $DOCUMENTED_NEXTAUTH documented, $LATEST_NEXTAUTH available${NC}"
    echo "   Update SKILL.md and README.md if needed"
  fi
fi

echo ""

# Check @auth/core
echo "📦 Checking @auth/core..."
LATEST_AUTH_CORE=$(npm view @auth/core version 2>/dev/null)

if [ -z "$LATEST_AUTH_CORE" ]; then
  echo -e "${RED}❌ Error: Could not fetch @auth/core version${NC}"
else
  if [ "$LATEST_AUTH_CORE" = "$DOCUMENTED_AUTH_CORE" ]; then
    echo -e "${GREEN}✅ @auth/core: $DOCUMENTED_AUTH_CORE (current)${NC}"
  else
    echo -e "${YELLOW}⚠️  @auth/core: $DOCUMENTED_AUTH_CORE documented, $LATEST_AUTH_CORE available${NC}"
    echo "   Update SKILL.md and README.md if needed"
  fi
fi

echo ""

# Check @auth/d1-adapter
echo "📦 Checking @auth/d1-adapter..."
LATEST_D1_ADAPTER=$(npm view @auth/d1-adapter version 2>/dev/null)

if [ -z "$LATEST_D1_ADAPTER" ]; then
  echo -e "${RED}❌ Error: Could not fetch @auth/d1-adapter version${NC}"
else
  if [ "$LATEST_D1_ADAPTER" = "$DOCUMENTED_D1_ADAPTER" ]; then
    echo -e "${GREEN}✅ @auth/d1-adapter: $DOCUMENTED_D1_ADAPTER (current)${NC}"
  else
    echo -e "${YELLOW}⚠️  @auth/d1-adapter: $DOCUMENTED_D1_ADAPTER documented, $LATEST_D1_ADAPTER available${NC}"
    echo "   Update SKILL.md and README.md if needed"
  fi
fi

echo ""

# Check other common packages
echo "📦 Checking related packages..."

# Next.js
LATEST_NEXT=$(npm view next version 2>/dev/null)
echo "   Next.js: $LATEST_NEXT"

# Hono
LATEST_HONO=$(npm view hono version 2>/dev/null)
echo "   Hono: $LATEST_HONO"

# @auth/prisma-adapter
LATEST_PRISMA_ADAPTER=$(npm view @auth/prisma-adapter version 2>/dev/null)
echo "   @auth/prisma-adapter: $LATEST_PRISMA_ADAPTER"

echo ""
echo "✨ Version check complete!"
echo ""
echo "📝 Files to update if versions changed:"
echo "   - SKILL.md (metadata section)"
echo "   - README.md (package versions section)"
echo "   - templates/nextjs/package.json"
echo "   - templates/cloudflare-workers/package.json"
