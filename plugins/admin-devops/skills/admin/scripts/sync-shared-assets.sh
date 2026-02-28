#!/bin/bash
set -euo pipefail

SKILLS_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ADMIN="$SKILLS_ROOT/admin"
DEVOPS="$SKILLS_ROOT/admin-devops"

cp "$ADMIN/references/profile-gate.md" "$DEVOPS/references/profile-gate.md"
cp "$ADMIN/scripts/log-admin-event.sh" "$DEVOPS/scripts/log-admin-event.sh"
cp "$ADMIN/scripts/Log-AdminEvent.ps1" "$DEVOPS/scripts/Log-AdminEvent.ps1"

echo "Synced shared assets from admin → admin-devops"
