#!/bin/bash

# OCI Infrastructure Setup Script (Centralized)
# This script creates the complete OCI infrastructure for KASM or Coolify deployment
# Based on successful deployment from KASM Container Admin thread
# Enhanced with server type support for multiple deployment scenarios

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Get server type from command line argument (default to kasm)
SERVER_TYPE="${1:-kasm}"

# All configuration must be passed via environment variables
# Claude sets these from .env.local before running this script

# Determine deployment type if not explicitly passed
if [ -z "$SERVER_TYPE" ] && [ -n "$DEPLOYMENT_TYPE" ]; then
    case "$DEPLOYMENT_TYPE" in
        kasm)
            SERVER_TYPE="kasm"
            ;;
        coolify)
            SERVER_TYPE="coolify"
            ;;
        both)
            echo "❌ Error: 'both' deployment requires specifying which server to provision first"
            echo "Usage: $0 [kasm|coolify]"
            exit 1
            ;;
        none)
            echo "❌ Error: DEPLOYMENT_TYPE is set to 'none'"
            exit 1
            ;;
        *)
            SERVER_TYPE="kasm"  # Default
            ;;
    esac
fi

# Variable aliasing for compatibility (server-admin uses SSH_PUBLIC_KEY_PATH)
SSH_KEY_PATH="${SSH_KEY_PATH:-$SSH_PUBLIC_KEY_PATH}"

# Load server-specific configuration based on server type
case "$SERVER_TYPE" in
    kasm)
        INSTANCE_OCPUS="${KASM_OCPUS:-4}"
        INSTANCE_MEMORY_GB="${KASM_MEMORY_GB:-24}"
        INSTANCE_STORAGE_GB="${KASM_STORAGE_GB:-80}"
        DISPLAY_NAME_PREFIX="${KASM_PREFIX:-KASM-}"
        SERVER_DESCRIPTION="KASM Workspaces"
        SECURITY_PORTS='[
            {"protocol":"6","source":"0.0.0.0/0","isStateless":false,"tcpOptions":{"destinationPortRange":{"min":22,"max":22}}},
            {"protocol":"6","source":"0.0.0.0/0","isStateless":false,"tcpOptions":{"destinationPortRange":{"min":8443,"max":8443}}},
            {"protocol":"6","source":"0.0.0.0/0","isStateless":false,"tcpOptions":{"destinationPortRange":{"min":3389,"max":3389}}},
            {"protocol":"6","source":"0.0.0.0/0","isStateless":false,"tcpOptions":{"destinationPortRange":{"min":3000,"max":4000}}}
        ]'
        ;;
    coolify)
        INSTANCE_OCPUS="${COOLIFY_OCPUS:-2}"
        INSTANCE_MEMORY_GB="${COOLIFY_MEMORY_GB:-12}"
        INSTANCE_STORAGE_GB="${COOLIFY_STORAGE_GB:-100}"
        DISPLAY_NAME_PREFIX="${COOLIFY_PREFIX:-Coolify-}"
        SERVER_DESCRIPTION="Coolify Self-Host"
        SECURITY_PORTS='[
            {"protocol":"6","source":"0.0.0.0/0","isStateless":false,"tcpOptions":{"destinationPortRange":{"min":22,"max":22}}},
            {"protocol":"6","source":"0.0.0.0/0","isStateless":false,"tcpOptions":{"destinationPortRange":{"min":8000,"max":8000}}},
            {"protocol":"6","source":"0.0.0.0/0","isStateless":false,"tcpOptions":{"destinationPortRange":{"min":80,"max":80}}},
            {"protocol":"6","source":"0.0.0.0/0","isStateless":false,"tcpOptions":{"destinationPortRange":{"min":443,"max":443}}},
            {"protocol":"6","source":"0.0.0.0/0","isStateless":false,"tcpOptions":{"destinationPortRange":{"min":6001,"max":6001}}},
            {"protocol":"6","source":"0.0.0.0/0","isStateless":false,"tcpOptions":{"destinationPortRange":{"min":6002,"max":6002}}}
        ]'
        ;;
    *)
        echo "❌ Unknown server type: $SERVER_TYPE"
        echo "Usage: $0 [kasm|coolify]"
        exit 1
        ;;
esac

# Required environment variables for OCI infrastructure
REQUIRED_VARS=(
    "TENANCY_OCID"
    "REGION"
    "COMPARTMENT_NAME"
    "VCN_CIDR"
    "SUBNET_CIDR"
    "SSH_KEY_PATH"
    "INSTANCE_SHAPE"
    "OPERATING_SYSTEM"
    "OPERATING_SYSTEM_VERSION"
)

echo "🚀 OCI Infrastructure Setup for $SERVER_DESCRIPTION"
echo "🏗️  Creating complete infrastructure on Oracle Cloud"
echo "📋 Server Type: $SERVER_TYPE"
echo "📋 Tenancy: $TENANCY_OCID"
echo "🌍 Region: $REGION"
echo "📦 Compartment: $COMPARTMENT_NAME"
echo "🔧 Instance: $INSTANCE_SHAPE ($INSTANCE_OCPUS OCPUs, ${INSTANCE_MEMORY_GB}GB RAM, ${INSTANCE_STORAGE_GB}GB Storage)"
echo "🏷️  Display Name Prefix: $DISPLAY_NAME_PREFIX"
echo ""

# Validate required environment variables
echo "📋 Validating environment configuration..."
for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var}" ]; then
        echo "❌ Missing required environment variable: $var"
        exit 1
    fi
    echo "✅ $var: ${!var}"
done
echo ""

# Function to run OCI CLI commands with error handling
run_oci_command() {
    local command="$1"
    local description="$2"
    local capture_output="$3"
    
    echo "🔧 $description"
    echo "📝 Executing: $command"
    
    if [ "$capture_output" = "true" ]; then
        local output
        if output=$(eval "$command" 2>&1); then
            echo "✅ $description completed successfully"
            echo "$output"
            echo ""
            return 0
        else
            echo "❌ $description failed"
            echo "Error output: $output"
            echo ""
            return 1
        fi
    else
        if eval "$command"; then
            echo "✅ $description completed successfully"
            echo ""
            return 0
        else
            echo "❌ $description failed"
            echo ""
            return 1
        fi
    fi
}

# Step 1: Create compartment
echo "📦 Step 1: Creating $COMPARTMENT_NAME compartment..."
COMPARTMENT_CMD="oci iam compartment create \
  --compartment-id $TENANCY_OCID \
  --name $COMPARTMENT_NAME \
  --description 'Compartment for $SERVER_DESCRIPTION deployment' \
  --wait-for-state ACTIVE"

if ! run_oci_command "$COMPARTMENT_CMD" "Creating $COMPARTMENT_NAME compartment"; then
    echo "⚠️  Compartment might already exist, continuing..."
fi

# Get compartment ID
echo "🔍 Retrieving compartment ID..."
COMPARTMENT_ID_CMD="oci iam compartment list \
  --compartment-id $TENANCY_OCID \
  --name $COMPARTMENT_NAME \
  --query 'data[0].id' \
  --raw-output"

if COMPARTMENT_ID=$(eval "$COMPARTMENT_ID_CMD"); then
    echo "✅ Compartment ID: $COMPARTMENT_ID"
    export COMPARTMENT_ID
    echo ""
else
    echo "❌ Failed to retrieve compartment ID"
    exit 1
fi

# Step 2: Create Virtual Cloud Network (VCN)
echo "🌐 Step 2: Creating Virtual Cloud Network..."
VCN_CMD="oci network vcn create \
  --compartment-id $COMPARTMENT_ID \
  --display-name '${DISPLAY_NAME_PREFIX}VCN' \
  --cidr-block $VCN_CIDR \
  --dns-label kasmvcn \
  --wait-for-state AVAILABLE"

if ! run_oci_command "$VCN_CMD" "Creating VCN"; then
    echo "⚠️  VCN might already exist, continuing..."
fi

# Get VCN ID
echo "🔍 Retrieving VCN ID..."
VCN_ID_CMD="oci network vcn list \
  --compartment-id $COMPARTMENT_ID \
  --display-name '${DISPLAY_NAME_PREFIX}VCN' \
  --query 'data[0].id' \
  --raw-output"

if VCN_ID=$(eval "$VCN_ID_CMD"); then
    echo "✅ VCN ID: $VCN_ID"
    export VCN_ID
    echo ""
else
    echo "❌ Failed to retrieve VCN ID"
    exit 1
fi

# Step 3: Create subnet
echo "🔗 Step 3: Creating subnet..."
SUBNET_CMD="oci network subnet create \
  --compartment-id $COMPARTMENT_ID \
  --vcn-id $VCN_ID \
  --display-name '${DISPLAY_NAME_PREFIX}Subnet' \
  --cidr-block $SUBNET_CIDR \
  --dns-label kasmsubnet \
  --wait-for-state AVAILABLE"

if ! run_oci_command "$SUBNET_CMD" "Creating subnet"; then
    echo "⚠️  Subnet might already exist, continuing..."
fi

# Get subnet ID
echo "🔍 Retrieving subnet ID..."
SUBNET_ID_CMD="oci network subnet list \
  --compartment-id $COMPARTMENT_ID \
  --vcn-id $VCN_ID \
  --display-name '${DISPLAY_NAME_PREFIX}Subnet' \
  --query 'data[0].id' \
  --raw-output"

if SUBNET_ID=$(eval "$SUBNET_ID_CMD"); then
    echo "✅ Subnet ID: $SUBNET_ID"
    export SUBNET_ID
    echo ""
else
    echo "❌ Failed to retrieve subnet ID"
    exit 1
fi

# Step 4: Create Internet Gateway
echo "🌍 Step 4: Creating Internet Gateway..."
IG_CMD="oci network internet-gateway create \
  --compartment-id $COMPARTMENT_ID \
  --vcn-id $VCN_ID \
  --display-name '${DISPLAY_NAME_PREFIX}IG' \
  --is-enabled true \
  --wait-for-state AVAILABLE"

if ! run_oci_command "$IG_CMD" "Creating Internet Gateway"; then
    echo "⚠️  Internet Gateway might already exist, continuing..."
fi

# Get Internet Gateway ID
echo "🔍 Retrieving Internet Gateway ID..."
IG_ID_CMD="oci network internet-gateway list \
  --compartment-id $COMPARTMENT_ID \
  --vcn-id $VCN_ID \
  --display-name '${DISPLAY_NAME_PREFIX}IG' \
  --query 'data[0].id' \
  --raw-output"

if IG_ID=$(eval "$IG_ID_CMD"); then
    echo "✅ Internet Gateway ID: $IG_ID"
    export IG_ID
    echo ""
else
    echo "❌ Failed to retrieve Internet Gateway ID"
    exit 1
fi

# Step 5: Configure routing
echo "🛣️  Step 5: Configuring default route..."
RT_ID_CMD="oci network route-table list \
  --compartment-id $COMPARTMENT_ID \
  --vcn-id $VCN_ID \
  --query 'data[?\"is-default\"==true].id | [0]' \
  --raw-output"

if RT_ID=$(eval "$RT_ID_CMD"); then
    echo "✅ Route Table ID: $RT_ID"
    export RT_ID
    
    # Update route table with default route
    ROUTE_CMD="oci network route-table update \
      --rt-id $RT_ID \
      --route-rules '[{\"destination\":\"0.0.0.0/0\",\"destinationType\":\"CIDR_BLOCK\",\"networkEntityId\":\"'$IG_ID'\"}]' \
      --force"
    
    run_oci_command "$ROUTE_CMD" "Adding default route to Internet Gateway"
else
    echo "❌ Failed to retrieve Route Table ID"
    exit 1
fi

# Step 6: Create security list for server
echo "🔒 Step 6: Creating security list for $SERVER_DESCRIPTION..."
SEC_LIST_CMD="oci network security-list create \
  --compartment-id $COMPARTMENT_ID \
  --vcn-id $VCN_ID \
  --display-name '${DISPLAY_NAME_PREFIX}SecList' \
  --ingress-security-rules '$SECURITY_PORTS' \
  --egress-security-rules '[{\"protocol\":\"all\",\"destination\":\"0.0.0.0/0\",\"isStateless\":false}]' \
  --wait-for-state AVAILABLE"

if ! run_oci_command "$SEC_LIST_CMD" "Creating $SERVER_DESCRIPTION security list"; then
    echo "⚠️  Security list might already exist, continuing..."
fi

# Get security list ID
echo "🔍 Retrieving security list ID..."
SEC_LIST_ID_CMD="oci network security-list list \
  --compartment-id $COMPARTMENT_ID \
  --vcn-id $VCN_ID \
  --display-name '${DISPLAY_NAME_PREFIX}SecList' \
  --query 'data[0].id' \
  --raw-output"

if SEC_LIST_ID=$(eval "$SEC_LIST_ID_CMD"); then
    echo "✅ Security List ID: $SEC_LIST_ID"
    export SEC_LIST_ID
    
    # Associate security list with subnet
    SUBNET_UPDATE_CMD="oci network subnet update \
      --subnet-id $SUBNET_ID \
      --security-list-ids '[\"'$SEC_LIST_ID'\"]' \
      --force"
    
    run_oci_command "$SUBNET_UPDATE_CMD" "Associating security list with subnet"
else
    echo "❌ Failed to retrieve security list ID"
    exit 1
fi

# Step 7: Get latest Ubuntu 22.04 ARM64 image
echo "💿 Step 7: Finding latest Ubuntu 22.04 ARM64 image..."
IMAGE_ID_CMD="oci compute image list \
  --compartment-id $TENANCY_OCID \
  --operating-system '$OPERATING_SYSTEM' \
  --operating-system-version '$OPERATING_SYSTEM_VERSION' \
  --shape $INSTANCE_SHAPE \
  --sort-by TIMECREATED \
  --sort-order DESC \
  --limit 1 \
  --query 'data[0].id' \
  --raw-output"

if IMAGE_ID=$(eval "$IMAGE_ID_CMD"); then
    echo "✅ Ubuntu Image ID: $IMAGE_ID"
    export IMAGE_ID
    echo ""
else
    echo "❌ Failed to retrieve Ubuntu image ID"
    exit 1
fi

# Step 8: Get availability domain
echo "🏢 Step 8: Getting availability domain..."
AD_CMD="oci iam availability-domain list \
  --compartment-id $COMPARTMENT_ID \
  --query 'data[0].name' \
  --raw-output"

if AVAILABILITY_DOMAIN=$(eval "$AD_CMD"); then
    echo "✅ Availability Domain: $AVAILABILITY_DOMAIN"
    export AVAILABILITY_DOMAIN
    echo ""
else
    echo "❌ Failed to retrieve availability domain"
    exit 1
fi

# Step 9: Launch compute instance
echo "🖥️  Step 9: Launching compute instance..."
echo "   Shape: $INSTANCE_SHAPE"
echo "   OCPUs: $INSTANCE_OCPUS"
echo "   Memory: ${INSTANCE_MEMORY_GB}GB"
echo "   Storage: ${INSTANCE_STORAGE_GB}GB"
echo "   OS: $OPERATING_SYSTEM $OPERATING_SYSTEM_VERSION"
echo ""

INSTANCE_CMD="oci compute instance launch \
  --compartment-id $COMPARTMENT_ID \
  --availability-domain '$AVAILABILITY_DOMAIN' \
  --shape $INSTANCE_SHAPE \
  --shape-config '{\"ocpus\":$INSTANCE_OCPUS,\"memoryInGBs\":$INSTANCE_MEMORY_GB}' \
  --subnet-id $SUBNET_ID \
  --assign-public-ip true \
  --image-id $IMAGE_ID \
  --ssh-authorized-keys-file $SSH_KEY_PATH \
  --display-name '${DISPLAY_NAME_PREFIX}Instance' \
  --wait-for-state RUNNING"

if ! run_oci_command "$INSTANCE_CMD" "Launching compute instance"; then
    exit 1
fi

# Get instance ID
echo "🔍 Retrieving instance ID..."
INSTANCE_ID_CMD="oci compute instance list \
  --compartment-id $COMPARTMENT_ID \
  --display-name '${DISPLAY_NAME_PREFIX}Instance' \
  --query 'data[0].id' \
  --raw-output"

if INSTANCE_ID=$(eval "$INSTANCE_ID_CMD"); then
    echo "✅ Instance ID: $INSTANCE_ID"
    export INSTANCE_ID
    echo ""
else
    echo "❌ Failed to retrieve instance ID"
    exit 1
fi

# Step 10: Get instance network details
echo "🌐 Step 10: Retrieving instance network details..."
PUBLIC_IP_CMD="oci compute instance list-vnics \
  --instance-id $INSTANCE_ID \
  --query 'data[0].\"public-ip\"' \
  --raw-output"

PRIVATE_IP_CMD="oci compute instance list-vnics \
  --instance-id $INSTANCE_ID \
  --query 'data[0].\"private-ip\"' \
  --raw-output"

if PUBLIC_IP=$(eval "$PUBLIC_IP_CMD") && PRIVATE_IP=$(eval "$PRIVATE_IP_CMD"); then
    echo "✅ Public IP: $PUBLIC_IP"
    echo "✅ Private IP: $PRIVATE_IP"
    export PUBLIC_IP
    export PRIVATE_IP
    echo ""
else
    echo "❌ Failed to retrieve instance IP addresses"
    exit 1
fi

# Step 11: Verify instance configuration
echo "📊 Step 11: Verifying instance configuration..."
INSTANCE_INFO_CMD="oci compute instance get --instance-id $INSTANCE_ID \
  --query 'data.{Name:\"display-name\",State:\"lifecycle-state\",Shape:shape,OCPUs:\"shape-config\".ocpus,Memory:\"shape-config\".\"memory-in-gbs\"}' \
  --output table"

run_oci_command "$INSTANCE_INFO_CMD" "Getting instance configuration" true

# Step 12: Test SSH connectivity
echo "🔑 Step 12: Testing SSH connectivity..."
echo "Waiting 60 seconds for instance to be fully ready..."
sleep 60

SSH_TEST_CMD="ssh -i ${SSH_KEY_PATH%.*} -o StrictHostKeyChecking=no -o ConnectTimeout=30 ubuntu@$PUBLIC_IP \
  'echo \"SSH connection successful\" && echo \"System info:\" && uname -a && echo \"Memory:\" && free -h && echo \"CPUs:\" && nproc'"

if run_oci_command "$SSH_TEST_CMD" "Testing SSH connectivity" true; then
    echo "🎉 SSH connectivity verified!"
else
    echo "⚠️  SSH test failed, but instance may still be starting up"
fi

# Step 13: Output configuration for Claude to save
echo "💾 Step 13: Outputting configuration..."
echo ""
echo "=== ENV_OUTPUT_START ==="
cat << EOF
# Generated OCI Infrastructure IDs ($(date))
COMPARTMENT_ID=$COMPARTMENT_ID
VCN_ID=$VCN_ID
SUBNET_ID=$SUBNET_ID
INTERNET_GATEWAY_ID=$IG_ID
ROUTE_TABLE_ID=$RT_ID
SECURITY_LIST_ID=$SEC_LIST_ID
INSTANCE_ID=$INSTANCE_ID
AVAILABILITY_DOMAIN=$AVAILABILITY_DOMAIN
UBUNTU_IMAGE_ID=$IMAGE_ID
INSTANCE_PUBLIC_IP=$PUBLIC_IP
INSTANCE_PRIVATE_IP=$PRIVATE_IP
EOF

# OCI Always Free uses ARM64 (A1.Flex shape)
echo "SERVER_ARCH=arm64"

# Add server-specific IP variable
if [ "$SERVER_TYPE" = "kasm" ]; then
    echo "KASM_SERVER_IP=$PUBLIC_IP"
elif [ "$SERVER_TYPE" = "coolify" ]; then
    echo "COOLIFY_SERVER_IP=$PUBLIC_IP"
fi
echo "=== ENV_OUTPUT_END ==="
echo ""
echo "✅ Claude should save the above values to .env.local"
echo ""

# Final summary
echo "🎉 OCI Infrastructure Setup Completed Successfully!"
echo ""
echo "📋 Infrastructure Summary:"
echo "   Server Type: $SERVER_TYPE ($SERVER_DESCRIPTION)"
echo "   Compartment: $COMPARTMENT_NAME ($COMPARTMENT_ID)"
echo "   VCN: ${DISPLAY_NAME_PREFIX}VCN ($VCN_ID)"
echo "   Subnet: ${DISPLAY_NAME_PREFIX}Subnet ($SUBNET_ID)"
echo "   Internet Gateway: ${DISPLAY_NAME_PREFIX}IG ($IG_ID)"
echo "   Security List: ${DISPLAY_NAME_PREFIX}SecList ($SEC_LIST_ID)"
echo "   Instance: ${DISPLAY_NAME_PREFIX}Instance ($INSTANCE_ID)"
echo ""
echo "🌐 Network Configuration:"
echo "   Public IP: $PUBLIC_IP"
echo "   Private IP: $PRIVATE_IP"
echo "   SSH Access: ssh -i ${SSH_KEY_PATH%.*} ubuntu@$PUBLIC_IP"
echo ""
echo "🔒 Security Configuration:"
echo "   SSH (22): ✅ Open"
if [ "$SERVER_TYPE" = "kasm" ]; then
    echo "   KASM Web (8443): ✅ Open"
    echo "   RDP (3389): ✅ Open"
    echo "   Session Ports (3000-4000): ✅ Open"
elif [ "$SERVER_TYPE" = "coolify" ]; then
    echo "   Coolify Web (8000): ✅ Open"
    echo "   HTTP (80): ✅ Open"
    echo "   HTTPS (443): ✅ Open"
    echo "   Proxy HTTP (6001): ✅ Open"
    echo "   Proxy HTTPS (6002): ✅ Open"
fi
echo ""
echo "🔧 Instance Specifications:"
echo "   Shape: $INSTANCE_SHAPE"
echo "   OCPUs: $INSTANCE_OCPUS"
echo "   Memory: ${INSTANCE_MEMORY_GB}GB"
echo "   Storage: ${INSTANCE_STORAGE_GB}GB"
echo "   OS: $OPERATING_SYSTEM $OPERATING_SYSTEM_VERSION"
echo "   Architecture: ARM64 (Ampere)"
echo ""
if [ "$SERVER_TYPE" = "kasm" ]; then
    echo "✅ Ready for KASM installation (run kasm/kasm-installation.sh)"
    echo "✅ Ready for Cloudflare tunnel setup (run kasm/cloudflare-tunnel-setup.sh)"
elif [ "$SERVER_TYPE" = "coolify" ]; then
    echo "✅ Ready for Coolify installation (run coolify/coolify-installation.sh)"
    echo "✅ Ready for Cloudflare tunnel setup (run coolify/coolify-cloudflare-tunnel-setup.sh)"
fi