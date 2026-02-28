# OCI Networking Guide

**Purpose**: Configure VCNs, subnets, security lists, and internet access.
**Prerequisites**: [OCI CLI configured](./CONFIG.md)

---

## Contents
- Overview
- Quick Setup
- Creating a VCN
- Creating a Subnet
- Internet Gateway
- Security Lists
- Protocol Numbers
- Common CIDR Blocks
- Troubleshooting
- Advanced Topics
- Quick Reference
- Next Steps

---

## Overview

OCI networking components:

```
┌─────────────────────────────────────────────────────────────┐
│ VCN (10.0.0.0/16)                                          │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ Public Subnet (10.0.1.0/24)                         │   │
│  │  ┌──────────────┐  ┌──────────────┐                │   │
│  │  │  Instance    │  │  Instance    │                │   │
│  │  │  10.0.1.10   │  │  10.0.1.11   │                │   │
│  │  └──────────────┘  └──────────────┘                │   │
│  └─────────────────────────────────────────────────────┘   │
│                              │                              │
│                    ┌─────────┴─────────┐                   │
│                    │ Internet Gateway   │                   │
│                    └─────────┬─────────┘                   │
└──────────────────────────────┼──────────────────────────────┘
                               │
                          Internet
```

---

## Quick Setup

The `oci-infrastructure-setup.sh` script handles all networking automatically. For manual setup:

```bash
# Set variables
export TENANCY_OCID="ocid1.tenancy.oc1..xxx"
export COMPARTMENT_ID="ocid1.compartment.oc1..xxx"
export VCN_CIDR="10.0.0.0/16"
export SUBNET_CIDR="10.0.1.0/24"
```

---

## Creating a VCN

```bash
VCN_ID=$(oci network vcn create \
  --compartment-id $COMPARTMENT_ID \
  --cidr-block $VCN_CIDR \
  --display-name "my-vcn" \
  --dns-label "myvcn" \
  --wait-for-state AVAILABLE \
  --query 'data.id' \
  --raw-output)

echo "VCN ID: $VCN_ID"
```

<details>
<summary><strong>VCN options explained</strong></summary>

| Option | Description |
|--------|-------------|
| `--cidr-block` | IP range for the VCN (e.g., 10.0.0.0/16) |
| `--display-name` | Human-readable name |
| `--dns-label` | DNS hostname prefix (alphanumeric, max 15 chars) |
| `--is-ipv6enabled` | Enable IPv6 (optional) |

**CIDR recommendations**:
- `/16` = 65,536 addresses (recommended)
- `/20` = 4,096 addresses
- `/24` = 256 addresses (minimum for most use cases)

</details>

---

## Creating a Subnet

```bash
SUBNET_ID=$(oci network subnet create \
  --compartment-id $COMPARTMENT_ID \
  --vcn-id $VCN_ID \
  --cidr-block $SUBNET_CIDR \
  --display-name "public-subnet" \
  --dns-label "public" \
  --wait-for-state AVAILABLE \
  --query 'data.id' \
  --raw-output)

echo "Subnet ID: $SUBNET_ID"
```

<details>
<summary><strong>Public vs Private subnets</strong></summary>

**Public subnet** (default):
- Instances can have public IPs
- Requires internet gateway for internet access
- Use for web servers, bastion hosts

**Private subnet**:
- No public IPs
- Use NAT gateway for outbound internet
- Use for databases, internal services

```bash
# Create private subnet
oci network subnet create \
  --compartment-id $COMPARTMENT_ID \
  --vcn-id $VCN_ID \
  --cidr-block "10.0.2.0/24" \
  --display-name "private-subnet" \
  --prohibit-public-ip-on-vnic true
```

</details>

---

## Internet Gateway

Required for instances to access the internet:

```bash
# Create internet gateway
IGW_ID=$(oci network internet-gateway create \
  --compartment-id $COMPARTMENT_ID \
  --vcn-id $VCN_ID \
  --display-name "internet-gateway" \
  --is-enabled true \
  --wait-for-state AVAILABLE \
  --query 'data.id' \
  --raw-output)

echo "Internet Gateway ID: $IGW_ID"
```

### Add Route to Default Route Table

```bash
# Get default route table ID
RT_ID=$(oci network route-table list \
  --compartment-id $COMPARTMENT_ID \
  --vcn-id $VCN_ID \
  --query 'data[0].id' \
  --raw-output)

# Add route for all internet traffic
oci network route-table update \
  --rt-id $RT_ID \
  --route-rules "[{\"destination\":\"0.0.0.0/0\",\"networkEntityId\":\"$IGW_ID\"}]" \
  --force
```

---

## Security Lists

Control inbound and outbound traffic:

```bash
# Get default security list
SL_ID=$(oci network security-list list \
  --compartment-id $COMPARTMENT_ID \
  --vcn-id $VCN_ID \
  --query 'data[0].id' \
  --raw-output)
```

### Common Rules

<details>
<summary><strong>SSH access (port 22)</strong></summary>

```bash
oci network security-list update \
  --security-list-id $SL_ID \
  --ingress-security-rules '[
    {
      "source": "0.0.0.0/0",
      "protocol": "6",
      "tcpOptions": {"destinationPortRange": {"min": 22, "max": 22}}
    }
  ]' \
  --force
```

**Security note**: Restrict source to your IP for production:
```json
"source": "203.0.113.10/32"
```

</details>

<details>
<summary><strong>HTTP/HTTPS (ports 80, 443)</strong></summary>

```bash
oci network security-list update \
  --security-list-id $SL_ID \
  --ingress-security-rules '[
    {
      "source": "0.0.0.0/0",
      "protocol": "6",
      "tcpOptions": {"destinationPortRange": {"min": 80, "max": 80}}
    },
    {
      "source": "0.0.0.0/0",
      "protocol": "6",
      "tcpOptions": {"destinationPortRange": {"min": 443, "max": 443}}
    }
  ]' \
  --force
```

</details>

<details>
<summary><strong>Coolify ports</strong></summary>

```bash
# Coolify requires: 22, 80, 443, 8000, 6001, 6002
oci network security-list update \
  --security-list-id $SL_ID \
  --ingress-security-rules '[
    {"source": "0.0.0.0/0", "protocol": "6", "tcpOptions": {"destinationPortRange": {"min": 22, "max": 22}}},
    {"source": "0.0.0.0/0", "protocol": "6", "tcpOptions": {"destinationPortRange": {"min": 80, "max": 80}}},
    {"source": "0.0.0.0/0", "protocol": "6", "tcpOptions": {"destinationPortRange": {"min": 443, "max": 443}}},
    {"source": "0.0.0.0/0", "protocol": "6", "tcpOptions": {"destinationPortRange": {"min": 8000, "max": 8000}}},
    {"source": "0.0.0.0/0", "protocol": "6", "tcpOptions": {"destinationPortRange": {"min": 6001, "max": 6002}}}
  ]' \
  --force
```

</details>

<details>
<summary><strong>KASM ports</strong></summary>

```bash
# KASM requires: 22, 8443, 3389, 3000-4000
oci network security-list update \
  --security-list-id $SL_ID \
  --ingress-security-rules '[
    {"source": "0.0.0.0/0", "protocol": "6", "tcpOptions": {"destinationPortRange": {"min": 22, "max": 22}}},
    {"source": "0.0.0.0/0", "protocol": "6", "tcpOptions": {"destinationPortRange": {"min": 8443, "max": 8443}}},
    {"source": "0.0.0.0/0", "protocol": "6", "tcpOptions": {"destinationPortRange": {"min": 3389, "max": 3389}}},
    {"source": "0.0.0.0/0", "protocol": "6", "tcpOptions": {"destinationPortRange": {"min": 3000, "max": 4000}}}
  ]' \
  --force
```

</details>

<details>
<summary><strong>All outbound traffic (egress)</strong></summary>

```bash
oci network security-list update \
  --security-list-id $SL_ID \
  --egress-security-rules '[
    {"destination": "0.0.0.0/0", "protocol": "all"}
  ]' \
  --force
```

</details>

---

## Protocol Numbers

| Protocol | Number |
|----------|--------|
| All | all |
| ICMP | 1 |
| TCP | 6 |
| UDP | 17 |

---

## Common CIDR Blocks

| CIDR | Addresses | Use Case |
|------|-----------|----------|
| 10.0.0.0/16 | 65,536 | Full VCN |
| 10.0.1.0/24 | 256 | Single subnet |
| 10.0.0.0/8 | 16.7M | Private range (RFC 1918) |
| 0.0.0.0/0 | All | Internet (any IP) |
| x.x.x.x/32 | 1 | Single IP |

---

## Troubleshooting

<details>
<summary><strong>Cannot reach internet from instance</strong></summary>

**Checklist**:
1. Internet gateway exists
2. Route table has 0.0.0.0/0 → IGW route
3. Security list allows outbound traffic
4. Instance has public IP

```bash
# Check routes
oci network route-table get --rt-id $RT_ID --query 'data."route-rules"'

# Check instance public IP
oci compute instance list-vnics --instance-id $INSTANCE_ID --query 'data[0]."public-ip"'
```

</details>

<details>
<summary><strong>Cannot SSH to instance</strong></summary>

**Checklist**:
1. Security list has port 22 ingress rule
2. Instance has public IP
3. Correct SSH key used
4. Instance is RUNNING state

```bash
# Check security list ingress rules
oci network security-list get --security-list-id $SL_ID --query 'data."ingress-security-rules"'

# Test connectivity
nc -zv <public-ip> 22
```

</details>

<details>
<summary><strong>CIDR block conflicts</strong></summary>

**Error**: "CIDR block conflicts with existing VCN"

**Fix**: Use non-overlapping CIDR blocks:
- VCN 1: 10.0.0.0/16
- VCN 2: 10.1.0.0/16
- VCN 3: 10.2.0.0/16

Or use different ranges:
- 172.16.0.0/16
- 192.168.0.0/16

</details>

---

## Advanced Topics

<details>
<summary><strong>VCN Peering</strong></summary>

Connect two VCNs:

```bash
# Create local peering gateway in VCN 1
LPG1_ID=$(oci network local-peering-gateway create \
  --compartment-id $COMPARTMENT_ID \
  --vcn-id $VCN1_ID \
  --display-name "lpg-to-vcn2" \
  --query 'data.id' --raw-output)

# Create local peering gateway in VCN 2
LPG2_ID=$(oci network local-peering-gateway create \
  --compartment-id $COMPARTMENT_ID \
  --vcn-id $VCN2_ID \
  --display-name "lpg-to-vcn1" \
  --query 'data.id' --raw-output)

# Connect them
oci network local-peering-gateway connect \
  --local-peering-gateway-id $LPG1_ID \
  --peer-id $LPG2_ID
```

</details>

<details>
<summary><strong>NAT Gateway (for private subnets)</strong></summary>

```bash
# Create NAT gateway
NAT_ID=$(oci network nat-gateway create \
  --compartment-id $COMPARTMENT_ID \
  --vcn-id $VCN_ID \
  --display-name "nat-gateway" \
  --query 'data.id' --raw-output)

# Add route for private subnet
oci network route-table update \
  --rt-id $PRIVATE_RT_ID \
  --route-rules "[{\"destination\":\"0.0.0.0/0\",\"networkEntityId\":\"$NAT_ID\"}]" \
  --force
```

</details>

<details>
<summary><strong>Service Gateway (for OCI services)</strong></summary>

Access OCI services (Object Storage, etc.) without internet:

```bash
# Get service OCID
SERVICE_ID=$(oci network service list --query 'data[0].id' --raw-output)

# Create service gateway
SGW_ID=$(oci network service-gateway create \
  --compartment-id $COMPARTMENT_ID \
  --vcn-id $VCN_ID \
  --services "[{\"serviceId\":\"$SERVICE_ID\"}]" \
  --display-name "service-gateway" \
  --query 'data.id' --raw-output)
```

</details>

---

## Quick Reference

| Component | Purpose |
|-----------|---------|
| VCN | Virtual network container |
| Subnet | IP address range within VCN |
| Internet Gateway | Connect to internet |
| NAT Gateway | Outbound internet for private subnets |
| Route Table | Traffic routing rules |
| Security List | Firewall rules (stateful) |

---

## Next Steps

- Return to [main skill](../SKILL.md)
- See [Troubleshooting Guide](./TROUBLESHOOTING.md) for more help
