#!/bin/bash

###############################################################################
# OCI Capacity Monitor and Auto-Deploy
#
# Purpose: Continuously monitor OCI capacity and automatically deploy a stack
#          when capacity becomes available.
#
# Usage: ./monitor-and-deploy.sh --stack-id <STACK_OCID> [OPTIONS]
#
# Required:
#   --stack-id OCID          OCI Resource Manager stack OCID to deploy
#
# Optional:
#   --profile PROFILE        OCI CLI profile to use (default: DEFAULT)
#   --interval SECONDS       Check interval in seconds (default: 180 = 3 minutes)
#   --region REGION          Region to check (default: stack's region)
#   --ocpus NUM             OCPUs to check for (default: 4)
#   --memory-gb NUM         Memory in GB to check for (default: 24)
#   --max-attempts NUM      Maximum check attempts (default: unlimited)
#   --notify-command CMD    Command to run on success (e.g., send notification)
#
# Examples:
#   # Monitor DEFAULT profile every 3 minutes
#   ./monitor-and-deploy.sh --stack-id ocid1.ormstack.oc1...
#
#   # Monitor DANIEL profile every 5 minutes
#   ./monitor-and-deploy.sh --stack-id ocid1.ormstack.oc1... --profile DANIEL --interval 300
#
#   # Check for smaller config (2 OCPUs, 12GB)
#   ./monitor-and-deploy.sh --stack-id ocid1.ormstack.oc1... --ocpus 2 --memory-gb 12
#
###############################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Default values
STACK_ID=""
PROFILE=""
PROFILE_FLAG=""
INTERVAL=300
REGION=""
REGION_FLAG=""
OCPUS=4
MEMORY_GB=24
MAX_ATTEMPTS=0
NOTIFY_COMMAND=""
SHAPE="VM.Standard.A1.Flex"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --stack-id)
            STACK_ID="$2"
            shift 2
            ;;
        --profile)
            PROFILE="$2"
            PROFILE_FLAG="--profile $PROFILE"
            shift 2
            ;;
        --interval)
            INTERVAL="$2"
            shift 2
            ;;
        --region)
            REGION="$2"
            REGION_FLAG="--region $REGION"
            shift 2
            ;;
        --ocpus)
            OCPUS="$2"
            shift 2
            ;;
        --memory-gb)
            MEMORY_GB="$2"
            shift 2
            ;;
        --max-attempts)
            MAX_ATTEMPTS="$2"
            shift 2
            ;;
        --notify-command)
            NOTIFY_COMMAND="$2"
            shift 2
            ;;
        -h|--help)
            grep '^#' "$0" | grep -v '#!/bin/bash' | sed 's/^# //g; s/^#//g'
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Validate required parameters
if [ -z "$STACK_ID" ]; then
    echo -e "${RED}ERROR: --stack-id is required${NC}"
    echo "Use --help for usage information"
    exit 1
fi

# Display configuration
echo ""
echo "╔═══════════════════════════════════════════════════════════════════════════╗"
echo "║         OCI Capacity Monitor and Auto-Deploy                             ║"
echo "╚═══════════════════════════════════════════════════════════════════════════╝"
echo ""
echo -e "${CYAN}Configuration:${NC}"
echo -e "  Stack ID:        ${BLUE}${STACK_ID}${NC}"
echo -e "  Profile:         ${BLUE}${PROFILE:-DEFAULT}${NC}"
echo -e "  Check interval:  ${BLUE}${INTERVAL}s ($(($INTERVAL / 60)) minutes)${NC}"
echo -e "  Target capacity: ${BLUE}${OCPUS} OCPUs, ${MEMORY_GB}GB RAM${NC}"
echo -e "  Max attempts:    ${BLUE}${MAX_ATTEMPTS:-unlimited}${NC}"
echo ""

# Get stack details
echo -e "${BLUE}Fetching stack details...${NC}"
STACK_INFO=$(oci resource-manager stack get $PROFILE_FLAG --stack-id "$STACK_ID" 2>/dev/null || echo "")

if [ -z "$STACK_INFO" ]; then
    echo -e "${RED}ERROR: Unable to retrieve stack information. Check stack ID and credentials.${NC}"
    exit 1
fi

STACK_NAME=$(echo "$STACK_INFO" | python3 -c "import sys, json; print(json.load(sys.stdin)['data']['display-name'])")
STACK_REGION=$(echo "$STACK_INFO" | python3 -c "import sys, json; print(json.load(sys.stdin)['data']['id'].split('.')[3])")
STACK_COMPARTMENT=$(echo "$STACK_INFO" | python3 -c "import sys, json; print(json.load(sys.stdin)['data']['compartment-id'])")

if [ -z "$REGION" ]; then
    REGION="$STACK_REGION"
    REGION_FLAG="--region $REGION"
fi

echo -e "${GREEN}✓ Stack: $STACK_NAME${NC}"
echo -e "${GREEN}✓ Region: $REGION${NC}"
echo -e "${GREEN}✓ Compartment: $STACK_COMPARTMENT${NC}"
echo ""

# Get tenancy OCID
TENANCY_OCID=$(oci iam availability-domain list $PROFILE_FLAG --query 'data[0]."compartment-id"' --raw-output 2>/dev/null)

# Get availability domains
AVAILABILITY_DOMAINS=$(oci iam availability-domain list $PROFILE_FLAG $REGION_FLAG --compartment-id "$TENANCY_OCID" 2>/dev/null | python3 -c "import sys, json; print('\n'.join([d['name'] for d in json.load(sys.stdin)['data']]))" 2>/dev/null || echo "")

if [ -z "$AVAILABILITY_DOMAINS" ]; then
    echo -e "${RED}ERROR: No availability domains found in region $REGION${NC}"
    exit 1
fi

AD_COUNT=$(echo "$AVAILABILITY_DOMAINS" | wc -l)
echo -e "${GREEN}✓ Found $AD_COUNT availability domain(s) to monitor${NC}"
echo ""

# Function to check capacity for a single AD
check_capacity() {
    local ad="$1"

    local result
    result=$(oci compute compute-capacity-report create \
        $PROFILE_FLAG \
        $REGION_FLAG \
        --compartment-id "$TENANCY_OCID" \
        --availability-domain "$ad" \
        --shape-availabilities "[{
            \"instanceShape\": \"$SHAPE\",
            \"instanceShapeConfig\": {
                \"ocpus\": $OCPUS,
                \"memoryInGBs\": $MEMORY_GB
            }
        }]" 2>&1) || true

    if echo "$result" | grep -q '"availability-status": "AVAILABLE"'; then
        return 0
    else
        return 1
    fi
}

# Function to deploy stack
deploy_stack() {
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                    CAPACITY AVAILABLE - DEPLOYING                         ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    echo -e "${CYAN}Creating apply job for stack...${NC}"

    APPLY_JOB=$(oci resource-manager job create-apply-job \
        $PROFILE_FLAG \
        --stack-id "$STACK_ID" \
        --execution-plan-strategy AUTO_APPROVED 2>/dev/null || echo "")

    if [ -z "$APPLY_JOB" ]; then
        echo -e "${RED}✗ Failed to create apply job${NC}"
        return 1
    fi

    JOB_ID=$(echo "$APPLY_JOB" | python3 -c "import sys, json; print(json.load(sys.stdin)['data']['id'])")

    echo -e "${GREEN}✓ Apply job created: $JOB_ID${NC}"
    echo ""
    echo -e "${CYAN}Stack deployment initiated successfully!${NC}"
    echo ""
    echo -e "Monitor job progress with:"
    echo -e "  ${BLUE}oci resource-manager job get $PROFILE_FLAG --job-id $JOB_ID${NC}"
    echo ""
    echo -e "View logs with:"
    echo -e "  ${BLUE}oci resource-manager job get-job-logs $PROFILE_FLAG --job-id $JOB_ID${NC}"
    echo ""

    # Run notification command if provided
    if [ -n "$NOTIFY_COMMAND" ]; then
        echo -e "${CYAN}Running notification command...${NC}"
        eval "$NOTIFY_COMMAND" || echo -e "${YELLOW}⚠ Notification command failed${NC}"
    fi

    return 0
}

# Main monitoring loop
attempt=0
start_time=$(date +%s)

echo "═══════════════════════════════════════════════════════════════════════════"
echo -e "${CYAN}Starting capacity monitoring...${NC}"
echo "═══════════════════════════════════════════════════════════════════════════"
echo ""

while true; do
    attempt=$((attempt + 1))
    current_time=$(date +%s)
    elapsed=$((current_time - start_time))
    elapsed_mins=$((elapsed / 60))

    echo -e "${MAGENTA}[Attempt $attempt - $(date '+%Y-%m-%d %H:%M:%S') - Elapsed: ${elapsed_mins}m]${NC}"

    # Check capacity in each AD
    available_ad=""
    for ad in $AVAILABILITY_DOMAINS; do
        echo -n "  Checking $ad... "
        if check_capacity "$ad"; then
            echo -e "${GREEN}✓ AVAILABLE${NC}"
            available_ad="$ad"
            break
        else
            echo -e "${RED}✗ No capacity${NC}"
        fi
    done

    # If capacity found, deploy
    if [ -n "$available_ad" ]; then
        echo ""
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${GREEN}SUCCESS! Capacity found in: $available_ad${NC}"
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

        if deploy_stack; then
            exit 0
        else
            echo -e "${YELLOW}⚠ Deploy failed, continuing monitoring...${NC}"
        fi
    fi

    # Check if max attempts reached
    if [ $MAX_ATTEMPTS -gt 0 ] && [ $attempt -ge $MAX_ATTEMPTS ]; then
        echo ""
        echo -e "${YELLOW}Maximum attempts ($MAX_ATTEMPTS) reached. Exiting.${NC}"
        exit 1
    fi

    # Wait before next check
    echo -e "${BLUE}  ⏳ Waiting ${INTERVAL}s until next check...${NC}"
    echo ""
    sleep $INTERVAL
done
