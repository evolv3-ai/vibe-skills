#!/bin/bash

###############################################################################
# OCI Always Free Tier Capacity Checker
#
# Purpose: Check availability of VM.Standard.A1.Flex instances across all
#          availability domains before attempting Terraform deployments.
#
# Usage: ./check-oci-capacity.sh [region] [--profile PROFILE_NAME]
#        If region is not specified, uses current OCI CLI default region
#        If profile is not specified, uses DEFAULT profile
#
# Examples:
#   ./check-oci-capacity.sh                          # Use DEFAULT profile, home region
#   ./check-oci-capacity.sh us-ashburn-1             # Use DEFAULT profile, specified region
#   ./check-oci-capacity.sh --profile DANIEL         # Use DANIEL profile, home region
#   ./check-oci-capacity.sh ca-montreal-1 --profile DANIEL  # Use DANIEL profile, specified region
#
# Requirements:
#   - OCI CLI configured with valid credentials
#   - Appropriate IAM permissions to list availability domains and compute capacity
###############################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SHAPE="VM.Standard.A1.Flex"
ALWAYS_FREE_OCPUS=4
ALWAYS_FREE_MEMORY_GB=24

# Parse arguments
REGION=""
PROFILE=""
PROFILE_FLAG=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --profile)
            PROFILE="$2"
            PROFILE_FLAG="--profile $PROFILE"
            shift 2
            ;;
        -*)
            echo -e "${RED}Unknown option: $1${NC}"
            echo "Usage: $0 [region] [--profile PROFILE_NAME]"
            exit 1
            ;;
        *)
            REGION="$1"
            shift
            ;;
    esac
done

# Display profile information
if [ -n "$PROFILE" ]; then
    echo -e "${BLUE}Using profile: $PROFILE${NC}"
else
    echo -e "${BLUE}Using profile: DEFAULT${NC}"
fi

# Set region
REGION_FLAG=""
if [ -n "$REGION" ]; then
    REGION_FLAG="--region $REGION"
    echo -e "${BLUE}Using region: $REGION${NC}"
else
    REGION=$(oci iam region-subscription list $PROFILE_FLAG --query 'data[?"is-home-region"]|[0]."region-name"' --raw-output 2>/dev/null || echo "")
    if [ -n "$REGION" ]; then
        echo -e "${BLUE}Using home region: $REGION${NC}"
        REGION_FLAG="--region $REGION"
    fi
fi

echo ""
echo "╔═══════════════════════════════════════════════════════════════════════════╗"
echo "║         OCI Always Free Tier A1 Flex Capacity Check                      ║"
echo "╚═══════════════════════════════════════════════════════════════════════════╝"
echo ""

# Get tenancy OCID
echo -e "${BLUE}Getting tenancy information...${NC}"
TENANCY_OCID=$(oci iam availability-domain list $PROFILE_FLAG --query 'data[0]."compartment-id"' --raw-output 2>/dev/null)

if [ -z "$TENANCY_OCID" ]; then
    echo -e "${RED}ERROR: Unable to retrieve tenancy OCID. Please check your OCI CLI configuration.${NC}"
    echo "Run: oci setup config"
    exit 1
fi

echo -e "${GREEN}✓ Tenancy OCID: ${TENANCY_OCID}${NC}"
echo ""

# Get all availability domains
echo -e "${BLUE}Fetching availability domains...${NC}"
AVAILABILITY_DOMAINS=$(oci iam availability-domain list $PROFILE_FLAG $REGION_FLAG --compartment-id "$TENANCY_OCID" 2>/dev/null | python3 -c "import sys, json; print('\n'.join([d['name'] for d in json.load(sys.stdin)['data']]))" 2>/dev/null || echo "")

if [ -z "$AVAILABILITY_DOMAINS" ]; then
    echo -e "${RED}ERROR: No availability domains found.${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Found availability domains${NC}"
echo ""

# Function to check capacity for a single AD
check_capacity() {
    local ad="$1"
    local ocpus="$2"
    local memory="$3"

    echo -e "${BLUE}Checking: $ad${NC}"
    echo "  Shape: $SHAPE"
    echo "  Config: ${ocpus} OCPUs, ${memory}GB RAM"

    # Create capacity report
    local result
    result=$(oci compute compute-capacity-report create \
        $PROFILE_FLAG \
        $REGION_FLAG \
        --compartment-id "$TENANCY_OCID" \
        --availability-domain "$ad" \
        --shape-availabilities "[{
            \"instanceShape\": \"$SHAPE\",
            \"instanceShapeConfig\": {
                \"ocpus\": $ocpus,
                \"memoryInGBs\": $memory
            }
        }]" 2>&1) || true

    # Parse result for availability status
    if echo "$result" | grep -q '"availability-status": "AVAILABLE"'; then
        echo -e "  ${GREEN}✓ AVAILABLE${NC}"
        return 0
    elif echo "$result" | grep -q '"availability-status": "OUT_OF_HOST_CAPACITY"'; then
        echo -e "  ${RED}✗ OUT OF CAPACITY${NC}"
        return 1
    elif echo "$result" | grep -q '"availability-status": "CONSTRAINT_ERROR"'; then
        echo -e "  ${YELLOW}⚠ CONSTRAINT ERROR (may work with different config)${NC}"
        return 2
    else
        echo -e "  ${YELLOW}? UNKNOWN (check manually)${NC}"
        echo "  Response: $result"
        return 3
    fi
}

# Track results
AVAILABLE_ADS=()
UNAVAILABLE_ADS=()
ERROR_ADS=()

echo "═══════════════════════════════════════════════════════════════════════════"
echo "  Testing Always Free Tier Configuration (4 OCPUs, 24GB RAM)"
echo "═══════════════════════════════════════════════════════════════════════════"
echo ""

# Check each availability domain
while IFS= read -r ad; do
    if check_capacity "$ad" "$ALWAYS_FREE_OCPUS" "$ALWAYS_FREE_MEMORY_GB"; then
        AVAILABLE_ADS+=("$ad")
    elif [ $? -eq 1 ]; then
        UNAVAILABLE_ADS+=("$ad")
    else
        ERROR_ADS+=("$ad")
    fi
    echo ""
done <<< "$AVAILABILITY_DOMAINS"

# Summary
echo "═══════════════════════════════════════════════════════════════════════════"
echo "  SUMMARY"
echo "═══════════════════════════════════════════════════════════════════════════"
echo ""

if [ ${#AVAILABLE_ADS[@]} -gt 0 ]; then
    echo -e "${GREEN}Available Availability Domains (${#AVAILABLE_ADS[@]}):${NC}"
    for ad in "${AVAILABLE_ADS[@]}"; do
        echo -e "  ${GREEN}✓${NC} $ad"
    done
    echo ""
fi

if [ ${#UNAVAILABLE_ADS[@]} -gt 0 ]; then
    echo -e "${RED}Unavailable Availability Domains (${#UNAVAILABLE_ADS[@]}):${NC}"
    for ad in "${UNAVAILABLE_ADS[@]}"; do
        echo -e "  ${RED}✗${NC} $ad"
    done
    echo ""
fi

if [ ${#ERROR_ADS[@]} -gt 0 ]; then
    echo -e "${YELLOW}Availability Domains with Errors (${#ERROR_ADS[@]}):${NC}"
    for ad in "${ERROR_ADS[@]}"; do
        echo -e "  ${YELLOW}?${NC} $ad"
    done
    echo ""
fi

# Recommendations
echo "═══════════════════════════════════════════════════════════════════════════"
echo "  RECOMMENDATIONS"
echo "═══════════════════════════════════════════════════════════════════════════"
echo ""

if [ ${#AVAILABLE_ADS[@]} -gt 0 ]; then
    echo -e "${GREEN}✓ You can deploy to the following AD(s):${NC}"
    for ad in "${AVAILABLE_ADS[@]}"; do
        echo ""
        echo "  Update terraform.tfvars with:"
        echo -e "    ${BLUE}availability_domain = \"$ad\"${NC}"
    done
    echo ""
    echo "  Then run: terraform apply"
    exit 0
else
    echo -e "${RED}✗ No availability domains have capacity for Always Free A1 instances.${NC}"
    echo ""
    echo "  Options:"
    echo "    1. Try again later (capacity changes frequently)"
    echo "    2. Try a different region with: $0 <region-name>"
    echo "    3. Check for smaller configurations (2 OCPUs, 12GB RAM)"
    echo ""

    # Check smaller configuration
    echo -e "${YELLOW}Checking smaller configuration (2 OCPUs, 12GB RAM)...${NC}"
    echo ""

    SMALL_AVAILABLE_ADS=()
    while IFS= read -r ad; do
        if check_capacity "$ad" 2 12; then
            SMALL_AVAILABLE_ADS+=("$ad")
        fi
        echo ""
    done <<< "$AVAILABILITY_DOMAINS"

    if [ ${#SMALL_AVAILABLE_ADS[@]} -gt 0 ]; then
        echo -e "${GREEN}✓ Smaller configuration available in:${NC}"
        for ad in "${SMALL_AVAILABLE_ADS[@]}"; do
            echo "  - $ad"
        done
        echo ""
        echo "  You can deploy Coolify or KASM (single server) to:"
        for ad in "${SMALL_AVAILABLE_ADS[@]}"; do
            echo "    availability_domain = \"$ad\""
        done
    fi

    exit 1
fi
