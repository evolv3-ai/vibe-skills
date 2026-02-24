#!/bin/bash

# OCI Compartment Cleanup Script
# Deletes all resources in a compartment in the correct order to avoid dependency issues
# Usage: ./cleanup-compartment.sh <compartment-ocid> [region]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_step() {
    echo -e "${BLUE}================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================================${NC}"
}

print_info() {
    echo -e "${YELLOW}$1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Check arguments
if [ $# -lt 1 ]; then
    echo -e "${RED}Usage: $0 <compartment-ocid> [region]${NC}"
    echo ""
    echo "Examples:"
    echo "  $0 ocid1.compartment.oc1..aaaaaaaa..."
    echo "  $0 ocid1.compartment.oc1..aaaaaaaa... us-ashburn-1"
    echo ""
    echo "⚠️  WARNING: This script will DELETE ALL RESOURCES in the specified compartment!"
    exit 1
fi

COMPARTMENT_ID="$1"
REGION="${2:-$(oci iam region-subscription list --query 'data[0]."region-name"' --raw-output 2>/dev/null || echo 'us-ashburn-1')}"

# Validate compartment exists
print_step "VALIDATING COMPARTMENT"
if ! oci iam compartment get --compartment-id "$COMPARTMENT_ID" >/dev/null 2>&1; then
    print_error "Compartment not found or access denied: $COMPARTMENT_ID"
    exit 1
fi

COMPARTMENT_NAME=$(oci iam compartment get --compartment-id "$COMPARTMENT_ID" --query 'data.name' --raw-output 2>/dev/null || echo "Unknown")
print_info "Compartment: $COMPARTMENT_NAME"
print_info "Compartment ID: $COMPARTMENT_ID"
print_info "Region: $REGION"

echo ""
print_warning "This script will DELETE ALL RESOURCES in compartment: $COMPARTMENT_NAME"
print_warning "This action is IRREVERSIBLE!"
echo ""
read -p "Are you absolutely sure you want to continue? Type 'DELETE' to confirm: " confirmation

if [ "$confirmation" != "DELETE" ]; then
    print_info "Operation cancelled"
    exit 0
fi

# Function to wait for resource termination
wait_for_termination() {
    local resource_type="$1"
    local check_command="$2"
    local max_wait=300  # 5 minutes
    local wait_time=0

    print_info "Waiting for $resource_type to be deleted..."

    while [ $wait_time -lt $max_wait ]; do
        if eval "$check_command" >/dev/null 2>&1; then
            local count=$(eval "$check_command" | jq '.data | length' 2>/dev/null || echo "0")
            if [ "$count" = "0" ]; then
                print_success "$resource_type deleted successfully"
                return 0
            fi
            echo -n "."
            sleep 10
            wait_time=$((wait_time + 10))
        else
            print_success "$resource_type deleted successfully"
            return 0
        fi
    done

    print_warning "$resource_type still exists after ${max_wait}s, continuing..."
}

# Function to delete volume attachments
delete_volume_attachments() {
    print_step "STEP 1: DELETING VOLUME ATTACHMENTS"

    # Get all volume attachments
    local attachments=$(oci compute volume-attachment list --compartment-id "$COMPARTMENT_ID" --region "$REGION" --all 2>/dev/null | jq -r '.data[] | select(.["lifecycle-state"] != "DETACHED") | .id' 2>/dev/null || echo "")

    if [ -n "$attachments" ]; then
        echo "$attachments" | while read -r attachment_id; do
            if [ -n "$attachment_id" ]; then
                print_info "Detaching volume: $attachment_id"
                oci compute volume-attachment detach --volume-attachment-id "$attachment_id" --force --wait-for-state DETACHED >/dev/null 2>&1 || print_warning "Failed to detach volume: $attachment_id"
            fi
        done
        wait_for_termination "Volume Attachments" "oci compute volume-attachment list --compartment-id '$COMPARTMENT_ID' --region '$REGION' --all | jq '.data[] | select(.[\"lifecycle-state\"] != \"DETACHED\")'"
    else
        print_success "No volume attachments to delete"
    fi
}

# Function to delete compute instances
delete_compute_instances() {
    print_step "STEP 2: TERMINATING COMPUTE INSTANCES"

    local instances=$(oci compute instance list --compartment-id "$COMPARTMENT_ID" --region "$REGION" --all 2>/dev/null | jq -r '.data[] | select(.["lifecycle-state"] != "TERMINATED") | .id' 2>/dev/null || echo "")

    if [ -n "$instances" ]; then
        echo "$instances" | while read -r instance_id; do
            if [ -n "$instance_id" ]; then
                local instance_name=$(oci compute instance get --instance-id "$instance_id" --query 'data."display-name"' --raw-output 2>/dev/null || echo "Unknown")
                print_info "Terminating instance: $instance_name ($instance_id)"
                oci compute instance terminate --instance-id "$instance_id" --force >/dev/null 2>&1 || print_warning "Failed to terminate instance: $instance_id"
            fi
        done
        wait_for_termination "Compute Instances" "oci compute instance list --compartment-id '$COMPARTMENT_ID' --region '$REGION' --all | jq '.data[] | select(.[\"lifecycle-state\"] != \"TERMINATED\")'"
    else
        print_success "No compute instances to terminate"
    fi
}

# Function to delete block volumes
delete_block_volumes() {
    print_step "STEP 3: DELETING BLOCK VOLUMES"

    local volumes=$(oci bv volume list --compartment-id "$COMPARTMENT_ID" --region "$REGION" --all 2>/dev/null | jq -r '.data[] | select(.["lifecycle-state"] != "TERMINATED") | .id' 2>/dev/null || echo "")

    if [ -n "$volumes" ]; then
        echo "$volumes" | while read -r volume_id; do
            if [ -n "$volume_id" ]; then
                local volume_name=$(oci bv volume get --volume-id "$volume_id" --query 'data."display-name"' --raw-output 2>/dev/null || echo "Unknown")
                print_info "Deleting block volume: $volume_name ($volume_id)"
                oci bv volume delete --volume-id "$volume_id" --force >/dev/null 2>&1 || print_warning "Failed to delete volume: $volume_id"
            fi
        done
        wait_for_termination "Block Volumes" "oci bv volume list --compartment-id '$COMPARTMENT_ID' --region '$REGION' --all | jq '.data[] | select(.[\"lifecycle-state\"] != \"TERMINATED\")'"
    else
        print_success "No block volumes to delete"
    fi
}

# Function to delete boot volumes (orphaned ones)
delete_boot_volumes() {
    print_step "STEP 4: DELETING BOOT VOLUMES"

    local boot_volumes=$(oci bv boot-volume list --compartment-id "$COMPARTMENT_ID" --region "$REGION" --all 2>/dev/null | jq -r '.data[] | select(.["lifecycle-state"] != "TERMINATED") | .id' 2>/dev/null || echo "")

    if [ -n "$boot_volumes" ]; then
        echo "$boot_volumes" | while read -r boot_volume_id; do
            if [ -n "$boot_volume_id" ]; then
                local boot_volume_name=$(oci bv boot-volume get --boot-volume-id "$boot_volume_id" --query 'data."display-name"' --raw-output 2>/dev/null || echo "Unknown")
                print_info "Deleting boot volume: $boot_volume_name ($boot_volume_id)"
                oci bv boot-volume delete --boot-volume-id "$boot_volume_id" --force >/dev/null 2>&1 || print_warning "Failed to delete boot volume: $boot_volume_id"
            fi
        done
        wait_for_termination "Boot Volumes" "oci bv boot-volume list --compartment-id '$COMPARTMENT_ID' --region '$REGION' --all | jq '.data[] | select(.[\"lifecycle-state\"] != \"TERMINATED\")'"
    else
        print_success "No boot volumes to delete"
    fi
}

# Function to delete load balancers
delete_load_balancers() {
    print_step "STEP 5: DELETING LOAD BALANCERS"

    local load_balancers=$(oci lb load-balancer list --compartment-id "$COMPARTMENT_ID" --region "$REGION" --all 2>/dev/null | jq -r '.data[] | select(.["lifecycle-state"] != "DELETED") | .id' 2>/dev/null || echo "")

    if [ -n "$load_balancers" ]; then
        echo "$load_balancers" | while read -r lb_id; do
            if [ -n "$lb_id" ]; then
                local lb_name=$(oci lb load-balancer get --load-balancer-id "$lb_id" --query 'data."display-name"' --raw-output 2>/dev/null || echo "Unknown")
                print_info "Deleting load balancer: $lb_name ($lb_id)"
                oci lb load-balancer delete --load-balancer-id "$lb_id" --force >/dev/null 2>&1 || print_warning "Failed to delete load balancer: $lb_id"
            fi
        done
        wait_for_termination "Load Balancers" "oci lb load-balancer list --compartment-id '$COMPARTMENT_ID' --region '$REGION' --all | jq '.data[] | select(.[\"lifecycle-state\"] != \"DELETED\")'"
    else
        print_success "No load balancers to delete"
    fi
}

# Function to delete subnets
delete_subnets() {
    print_step "STEP 6: DELETING SUBNETS"

    local subnets=$(oci network subnet list --compartment-id "$COMPARTMENT_ID" --region "$REGION" --all 2>/dev/null | jq -r '.data[] | select(.["lifecycle-state"] != "TERMINATED") | .id' 2>/dev/null || echo "")

    if [ -n "$subnets" ]; then
        echo "$subnets" | while read -r subnet_id; do
            if [ -n "$subnet_id" ]; then
                local subnet_name=$(oci network subnet get --subnet-id "$subnet_id" --query 'data."display-name"' --raw-output 2>/dev/null || echo "Unknown")
                print_info "Deleting subnet: $subnet_name ($subnet_id)"
                oci network subnet delete --subnet-id "$subnet_id" --force >/dev/null 2>&1 || print_warning "Failed to delete subnet: $subnet_id"
            fi
        done
        wait_for_termination "Subnets" "oci network subnet list --compartment-id '$COMPARTMENT_ID' --region '$REGION' --all | jq '.data[] | select(.[\"lifecycle-state\"] != \"TERMINATED\")'"
    else
        print_success "No subnets to delete"
    fi
}

# Function to delete internet gateways
delete_internet_gateways() {
    print_step "STEP 7: DELETING INTERNET GATEWAYS"

    local igws=$(oci network internet-gateway list --compartment-id "$COMPARTMENT_ID" --region "$REGION" --all 2>/dev/null | jq -r '.data[] | select(.["lifecycle-state"] != "TERMINATED") | .id' 2>/dev/null || echo "")

    if [ -n "$igws" ]; then
        echo "$igws" | while read -r igw_id; do
            if [ -n "$igw_id" ]; then
                local igw_name=$(oci network internet-gateway get --ig-id "$igw_id" --query 'data."display-name"' --raw-output 2>/dev/null || echo "Unknown")
                print_info "Deleting internet gateway: $igw_name ($igw_id)"
                oci network internet-gateway delete --ig-id "$igw_id" --force >/dev/null 2>&1 || print_warning "Failed to delete internet gateway: $igw_id"
            fi
        done
        wait_for_termination "Internet Gateways" "oci network internet-gateway list --compartment-id '$COMPARTMENT_ID' --region '$REGION' --all | jq '.data[] | select(.[\"lifecycle-state\"] != \"TERMINATED\")'"
    else
        print_success "No internet gateways to delete"
    fi
}

# Function to delete route tables (except default)
delete_route_tables() {
    print_step "STEP 8: DELETING ROUTE TABLES"

    local route_tables=$(oci network route-table list --compartment-id "$COMPARTMENT_ID" --region "$REGION" --all 2>/dev/null | jq -r '.data[] | select(.["lifecycle-state"] != "TERMINATED" and .["display-name"] != "Default Route Table for *") | .id' 2>/dev/null || echo "")

    if [ -n "$route_tables" ]; then
        echo "$route_tables" | while read -r rt_id; do
            if [ -n "$rt_id" ]; then
                local rt_name=$(oci network route-table get --rt-id "$rt_id" --query 'data."display-name"' --raw-output 2>/dev/null || echo "Unknown")
                # Skip default route tables
                if [[ "$rt_name" == *"Default Route Table"* ]]; then
                    print_info "Skipping default route table: $rt_name"
                    continue
                fi
                print_info "Deleting route table: $rt_name ($rt_id)"
                oci network route-table delete --rt-id "$rt_id" --force >/dev/null 2>&1 || print_warning "Failed to delete route table: $rt_id"
            fi
        done
        wait_for_termination "Route Tables" "oci network route-table list --compartment-id '$COMPARTMENT_ID' --region '$REGION' --all | jq '.data[] | select(.[\"lifecycle-state\"] != \"TERMINATED\" and .[\"display-name\"] != \"Default Route Table for *\")'"
    else
        print_success "No custom route tables to delete"
    fi
}

# Function to delete security lists (except default)
delete_security_lists() {
    print_step "STEP 9: DELETING SECURITY LISTS"

    local security_lists=$(oci network security-list list --compartment-id "$COMPARTMENT_ID" --region "$REGION" --all 2>/dev/null | jq -r '.data[] | select(.["lifecycle-state"] != "TERMINATED" and .["display-name"] != "Default Security List for *") | .id' 2>/dev/null || echo "")

    if [ -n "$security_lists" ]; then
        echo "$security_lists" | while read -r sl_id; do
            if [ -n "$sl_id" ]; then
                local sl_name=$(oci network security-list get --security-list-id "$sl_id" --query 'data."display-name"' --raw-output 2>/dev/null || echo "Unknown")
                # Skip default security lists
                if [[ "$sl_name" == *"Default Security List"* ]]; then
                    print_info "Skipping default security list: $sl_name"
                    continue
                fi
                print_info "Deleting security list: $sl_name ($sl_id)"
                oci network security-list delete --security-list-id "$sl_id" --force >/dev/null 2>&1 || print_warning "Failed to delete security list: $sl_id"
            fi
        done
        wait_for_termination "Security Lists" "oci network security-list list --compartment-id '$COMPARTMENT_ID' --region '$REGION' --all | jq '.data[] | select(.[\"lifecycle-state\"] != \"TERMINATED\" and .[\"display-name\"] != \"Default Security List for *\")'"
    else
        print_success "No custom security lists to delete"
    fi
}

# Function to delete VCNs
delete_vcns() {
    print_step "STEP 10: DELETING VCNs"

    local vcns=$(oci network vcn list --compartment-id "$COMPARTMENT_ID" --region "$REGION" --all 2>/dev/null | jq -r '.data[] | select(.["lifecycle-state"] != "TERMINATED") | .id' 2>/dev/null || echo "")

    if [ -n "$vcns" ]; then
        echo "$vcns" | while read -r vcn_id; do
            if [ -n "$vcn_id" ]; then
                local vcn_name=$(oci network vcn get --vcn-id "$vcn_id" --query 'data."display-name"' --raw-output 2>/dev/null || echo "Unknown")
                print_info "Deleting VCN: $vcn_name ($vcn_id)"
                oci network vcn delete --vcn-id "$vcn_id" --force >/dev/null 2>&1 || print_warning "Failed to delete VCN: $vcn_id"
            fi
        done
        wait_for_termination "VCNs" "oci network vcn list --compartment-id '$COMPARTMENT_ID' --region '$REGION' --all | jq '.data[] | select(.[\"lifecycle-state\"] != \"TERMINATED\")'"
    else
        print_success "No VCNs to delete"
    fi
}

# Function to delete the compartment
delete_compartment() {
    print_step "STEP 11: DELETING COMPARTMENT"

    print_info "Deleting compartment: $COMPARTMENT_NAME ($COMPARTMENT_ID)"

    # Wait a bit for all resources to be fully cleaned up
    print_info "Waiting 30 seconds for resource cleanup to complete..."
    sleep 30

    if oci iam compartment delete --compartment-id "$COMPARTMENT_ID" --force >/dev/null 2>&1; then
        print_success "Compartment deletion initiated"
        print_info "Note: Compartment deletion can take several hours to complete"
        print_info "The compartment will show as 'DELETING' and then 'DELETED'"
    else
        print_warning "Failed to delete compartment - it may have remaining resources or dependencies"
        print_info "Check the OCI console for any remaining resources"
    fi
}

# Main execution
print_step "STARTING COMPARTMENT CLEANUP"
print_warning "Deleting all resources in compartment: $COMPARTMENT_NAME"

# Execute deletion steps in the correct order
delete_volume_attachments
delete_compute_instances
delete_block_volumes
delete_boot_volumes
delete_load_balancers
delete_subnets
delete_internet_gateways
delete_route_tables
delete_security_lists
delete_vcns
delete_compartment

print_step "CLEANUP COMPLETED"
print_success "All resources have been scheduled for deletion"
print_info "Some resources may take additional time to fully terminate"
print_info "Monitor the OCI console to verify complete deletion"