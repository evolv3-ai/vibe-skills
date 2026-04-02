#!/bin/bash

# DNS Fix Script for Coolify Cloudflare Tunnel
# This script fixes DNS resolution issues by ensuring the CNAME record is properly proxied
# Based on KASM DNS fix patterns with Coolify-specific optimizations

set -e

# Load environment variables (MCP-compliant approach)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Priority: 1. Environment variables (from MCP server), 2. .env file (backward compatibility)
if [ -f "$SCRIPT_DIR/.env" ]; then
    # Load .env as fallback, but don't override existing environment variables
    set -a  # automatically export all variables
    source "$SCRIPT_DIR/.env"
    set +a
    echo "⚠️  Loading .env file for backward compatibility"
    echo "⚠️  Recommended: Provide parameters via MCP server instead"
    echo ""
fi

echo "🔧 Fixing DNS Resolution for $TUNNEL_HOSTNAME..."
echo ""

# Validate required variables
# API variables: must be set for script to function
if [ -z "$CLOUDFLARE_API_TOKEN" ] || [ -z "$CLOUDFLARE_ZONE_ID" ] || [ -z "$DNS_RECORD_ID" ] || [ -z "$TUNNEL_ID" ] || [ -z "$CLOUDFLARE_ACCOUNT_ID" ]; then
    echo "❌ Missing required environment variables. Please run coolify-cloudflare-tunnel-setup.sh first."
    echo ""
    echo "Required variables:"
    echo "  CLOUDFLARE_API_TOKEN    - Cloudflare API token"
    echo "  CLOUDFLARE_ZONE_ID      - DNS zone ID"
    echo "  CLOUDFLARE_ACCOUNT_ID   - Cloudflare account ID"
    echo "  DNS_RECORD_ID           - DNS record ID for the tunnel hostname"
    echo "  TUNNEL_ID               - Cloudflare tunnel ID"
    echo "  TUNNEL_HOSTNAME         - Public hostname (e.g. coolify.example.com)"
    exit 1
fi

# Optional variables: used in diagnostic output — default to descriptive placeholders if not set
TUNNEL_NAME="${TUNNEL_NAME:-<tunnel-name>}"
COOLIFY_SERVER_IP="${COOLIFY_SERVER_IP:-<server-ip>}"
COOLIFY_PORT="${COOLIFY_PORT:-8000}"

# Step 1: Check current DNS record status
echo "🔍 Checking current DNS record status..."
CURRENT_RECORD=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/dns_records?name=$TUNNEL_HOSTNAME" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  -H "Content-Type: application/json")

echo "📊 Current record status:"
echo "$CURRENT_RECORD" | jq -r '.result[] | "   Type: \(.type), Content: \(.content), Proxied: \(.proxied)"' 2>/dev/null || \
echo "$CURRENT_RECORD" | grep -o '"type":"[^"]*"' | cut -d'"' -f4 | while read type; do
    content=$(echo "$CURRENT_RECORD" | grep -o '"content":"[^"]*"' | cut -d'"' -f4)
    proxied=$(echo "$CURRENT_RECORD" | grep -o '"proxied":[^,}]*' | cut -d':' -f2)
    echo "   Type: $type, Content: $content, Proxied: $proxied"
done

echo ""

# Step 2: Update DNS record to enable proxy (orange cloud)
echo "🔧 Updating DNS record to enable proxy (orange cloud)..."
HOSTNAME_PART=$(echo "$TUNNEL_HOSTNAME" | cut -d'.' -f1)

UPDATE_RESULT=$(curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/dns_records/$DNS_RECORD_ID" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  -H "Content-Type: application/json" \
  --data "{
    \"type\": \"CNAME\",
    \"name\": \"$HOSTNAME_PART\",
    \"content\": \"$TUNNEL_ID.cfargotunnel.com\",
    \"proxied\": true,
    \"comment\": \"Cloudflare Tunnel for Coolify - Fixed to enable IPv4/IPv6 resolution\"
  }")

# Check if update was successful
SUCCESS=$(echo "$UPDATE_RESULT" | grep -o '"success":[^,]*' | cut -d':' -f2)
if [ "$SUCCESS" = "true" ]; then
    echo "✅ DNS record updated successfully!"
    echo ""
    
    # Show updated record details
    echo "📋 Updated record details:"
    echo "$UPDATE_RESULT" | jq -r '.result | "   Type: \(.type), Content: \(.content), Proxied: \(.proxied)"' 2>/dev/null || \
    echo "   CNAME record updated and proxied"
    echo ""
    
    echo "🎉 DNS Fix Complete!"
    echo ""
    echo "📝 What was fixed:"
    echo "   ❌ Before: CNAME record may not have been proxied (gray cloud)"
    echo "   ✅ After:  CNAME record is now proxied (orange cloud)"
    echo ""
    echo "🌐 Expected results:"
    echo "   • $TUNNEL_HOSTNAME will now resolve to both IPv4 and IPv6 addresses"
    echo "   • Traffic will be secured and accelerated by Cloudflare"
    echo "   • DNS_PROBE_FINISHED_NXDOMAIN errors should be resolved"
    echo "   • Coolify will be accessible via the tunnel"
    echo ""
    echo "⏱️  DNS propagation time: 5-10 minutes globally"
    echo ""
    echo "🧪 Test the fix:"
    echo "   • Wait 5-10 minutes for DNS propagation"
    echo "   • Try accessing: https://$TUNNEL_HOSTNAME"
    echo "   • Check DNS resolution: nslookup $TUNNEL_HOSTNAME"
    echo "   • Verify Coolify loads: curl -I https://$TUNNEL_HOSTNAME"
    
else
    echo "❌ Failed to update DNS record"
    echo "Error details:"
    echo "$UPDATE_RESULT" | jq -r '.errors[]? | "   \(.message)"' 2>/dev/null || \
    echo "$UPDATE_RESULT"
    exit 1
fi

echo ""

# Step 3: Additional DNS verification and troubleshooting
echo "🔍 Step 3: Additional DNS verification..."

# Check if tunnel is properly configured
echo "🌐 Verifying tunnel configuration..."
TUNNEL_INFO=$(curl -s -X GET "https://api.cloudflare.com/client/v4/accounts/$CLOUDFLARE_ACCOUNT_ID/cfd_tunnel/$TUNNEL_ID" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN")

TUNNEL_STATUS=$(echo "$TUNNEL_INFO" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
if [ "$TUNNEL_STATUS" = "active" ]; then
    echo "✅ Tunnel is active and running"
else
    echo "⚠️  Tunnel status: $TUNNEL_STATUS"
    echo "   You may need to start the tunnel daemon on your server"
fi

echo ""

# Check tunnel configuration
echo "🔧 Verifying tunnel ingress configuration..."
TUNNEL_CONFIG=$(curl -s -X GET "https://api.cloudflare.com/client/v4/accounts/$CLOUDFLARE_ACCOUNT_ID/cfd_tunnel/$TUNNEL_ID/configurations" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN")

CONFIG_SUCCESS=$(echo "$TUNNEL_CONFIG" | grep -o '"success":[^,]*' | cut -d':' -f2)
if [ "$CONFIG_SUCCESS" = "true" ]; then
    echo "✅ Tunnel ingress configuration is present"
    
    # Check if our hostname is in the configuration
    if echo "$TUNNEL_CONFIG" | grep -q "$TUNNEL_HOSTNAME"; then
        echo "✅ Hostname $TUNNEL_HOSTNAME found in tunnel configuration"
    else
        echo "⚠️  Hostname $TUNNEL_HOSTNAME not found in tunnel configuration"
        echo "   You may need to re-run the tunnel setup script"
    fi
else
    echo "❌ Failed to retrieve tunnel configuration"
    echo "   You may need to re-run the tunnel setup script"
fi

echo ""

# Step 4: Provide troubleshooting guidance
echo "🛠️  Step 4: Troubleshooting guidance..."
echo ""
echo "If you're still experiencing issues, try these steps:"
echo ""
echo "1. 🔍 Check tunnel daemon status on your server:"
echo "   ssh ubuntu@$COOLIFY_SERVER_IP 'sudo systemctl status cloudflared-$TUNNEL_NAME'"
echo ""
echo "2. 📋 View tunnel logs:"
echo "   ssh ubuntu@$COOLIFY_SERVER_IP 'sudo journalctl -u cloudflared-$TUNNEL_NAME -f'"
echo ""
echo "3. 🔄 Restart tunnel daemon:"
echo "   ssh ubuntu@$COOLIFY_SERVER_IP 'sudo systemctl restart cloudflared-$TUNNEL_NAME'"
echo ""
echo "4. 🧪 Test local Coolify access:"
echo "   ssh ubuntu@$COOLIFY_SERVER_IP 'curl -I http://localhost:$COOLIFY_PORT'"
echo ""
echo "5. 🌐 Test DNS resolution:"
echo "   nslookup $TUNNEL_HOSTNAME"
echo "   dig $TUNNEL_HOSTNAME"
echo ""
echo "6. 🔗 Test tunnel connectivity:"
echo "   curl -I https://$TUNNEL_HOSTNAME"
echo ""
echo "7. 🔧 If tunnel daemon is not running, deploy it:"
echo "   cd $SCRIPT_DIR/config"
echo "   scp -r . ubuntu@$COOLIFY_SERVER_IP:/tmp/tunnel-config"
echo "   ssh ubuntu@$COOLIFY_SERVER_IP 'cd /tmp/tunnel-config && sudo bash deploy-tunnel.sh'"
echo ""

# Step 5: Final verification
echo "🎯 Step 5: Final verification..."
echo ""
echo "Expected behavior after DNS fix:"
echo "✅ DNS record is proxied (orange cloud in Cloudflare dashboard)"
echo "✅ $TUNNEL_HOSTNAME resolves to Cloudflare IP addresses"
echo "✅ HTTPS requests to $TUNNEL_HOSTNAME reach your Coolify instance"
echo "✅ Coolify web interface loads via the tunnel"
echo ""
echo "🌐 Access URLs:"
echo "   Direct: http://$COOLIFY_SERVER_IP:$COOLIFY_PORT"
echo "   Tunnel: https://$TUNNEL_HOSTNAME"
echo ""

echo "✅ DNS fix completed successfully!"
echo ""
echo "⏰ Please wait 5-10 minutes for DNS propagation, then test:"
echo "   https://$TUNNEL_HOSTNAME"