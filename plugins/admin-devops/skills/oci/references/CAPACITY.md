# OCI Capacity Guide

**Purpose**: Handle ARM instance capacity issues on OCI Always Free tier.
**Prerequisites**: [OCI CLI configured](./CONFIG.md)

---

## Contents
- Understanding Capacity
- Checking Capacity
- Automated Monitoring
- Strategies for Getting Capacity
- Understanding Availability Domains
- Error Messages
- Creating Resource Manager Stacks
- Quick Reference
- Next Steps

---

## Understanding Capacity

ARM A1.Flex instances on OCI Always Free tier are highly demanded. "OUT_OF_HOST_CAPACITY" errors are common and expected.

### Key Points

- Capacity varies by **availability domain** (AD) within a region
- Capacity fluctuates throughout the day
- Different regions have different availability
- You can split resources across ADs (e.g., 2 OCPU in AD-1, 2 OCPU in AD-2)

---

## Checking Capacity

### Quick Check

```bash
./scripts/check-oci-capacity.sh
```

### Options

```bash
# Specific region
./scripts/check-oci-capacity.sh us-ashburn-1

# With specific OCI profile
./scripts/check-oci-capacity.sh --profile PRODUCTION

# Check multiple regions
for region in us-ashburn-1 us-phoenix-1 ca-toronto-1 ca-montreal-1; do
  echo "=== Checking $region ==="
  ./scripts/check-oci-capacity.sh "$region"
done
```

<details>
<summary><strong>Manual capacity check</strong></summary>

```bash
# List availability domains
oci iam availability-domain list --query 'data[*].name' --output table

# Try to launch (dry-run style) - will fail with OUT_OF_HOST_CAPACITY if unavailable
oci compute instance launch \
  --availability-domain "xxxx:US-ASHBURN-AD-1" \
  --compartment-id $COMPARTMENT_ID \
  --shape VM.Standard.A1.Flex \
  --shape-config '{"ocpus":4,"memoryInGBs":24}' \
  --dry-run
```

</details>

---

## Automated Monitoring

When capacity is unavailable, use automated monitoring to deploy when it becomes available:

```bash
./scripts/monitor-and-deploy.sh --stack-id <STACK_OCID>
```

### Options

| Flag | Description | Default |
|------|-------------|---------|
| `--stack-id` | Resource Manager stack OCID (required) | - |
| `--profile` | OCI CLI profile | DEFAULT |
| `--interval` | Check interval in seconds | 180 (3 min) |
| `--region` | Region to check | Profile default |
| `--ocpus` | OCPUs to check for | 4 |
| `--memory-gb` | Memory to check for | 24 |
| `--max-attempts` | Stop after N attempts | unlimited |
| `--notify-command` | Command to run on success | - |

### Examples

```bash
# Basic monitoring
./scripts/monitor-and-deploy.sh --stack-id ocid1.ormstack.oc1..xxx

# Custom interval and limits
./scripts/monitor-and-deploy.sh \
  --stack-id ocid1.ormstack.oc1..xxx \
  --interval 300 \
  --max-attempts 100

# With notification
./scripts/monitor-and-deploy.sh \
  --stack-id ocid1.ormstack.oc1..xxx \
  --notify-command "curl -X POST https://hooks.slack.com/..."

# Check for smaller config
./scripts/monitor-and-deploy.sh \
  --stack-id ocid1.ormstack.oc1..xxx \
  --ocpus 2 \
  --memory-gb 12
```

---

## Strategies for Getting Capacity

<details>
<summary><strong>1. Try different availability domains</strong></summary>

Each region has 1-3 availability domains. Check all of them:

```bash
./scripts/check-oci-capacity.sh
```

The script automatically checks all ADs in your region.

</details>

<details>
<summary><strong>2. Try different regions</strong></summary>

Some regions have more capacity than others. Good options:

| Region | Identifier | Notes |
|--------|------------|-------|
| US East (Ashburn) | us-ashburn-1 | Popular but large |
| US West (Phoenix) | us-phoenix-1 | Often available |
| Canada (Toronto) | ca-toronto-1 | Good availability |
| Canada (Montreal) | ca-montreal-1 | Good availability |
| UK (London) | uk-london-1 | European option |
| Germany (Frankfurt) | eu-frankfurt-1 | European option |

```bash
# Add new region to your OCI config
oci setup config  # and add new profile for each region

# Or use region override
oci compute instance launch --region ca-montreal-1 ...
```

</details>

<details>
<summary><strong>3. Use smaller configuration</strong></summary>

Instead of full 4 OCPU / 24GB, try:
- 2 OCPU / 12GB (often more available)
- 1 OCPU / 6GB (highest availability)

```bash
# Check for 2 OCPU availability
./scripts/monitor-and-deploy.sh \
  --stack-id <STACK_OCID> \
  --ocpus 2 \
  --memory-gb 12
```

</details>

<details>
<summary><strong>4. Split across availability domains</strong></summary>

Total free tier is 4 OCPU + 24GB. You can split across instances:

- 2 instances × 2 OCPU / 12GB each
- 4 instances × 1 OCPU / 6GB each
- Mix: 1×3 OCPU + 1×1 OCPU

This increases chances of finding capacity in at least one AD.

</details>

<details>
<summary><strong>5. Optimal timing</strong></summary>

Capacity tends to be more available:
- Early morning (UTC)
- Weekends
- Beginning of month (when free tier resets)

Run the monitor script during these times for best results.

</details>

---

## Understanding Availability Domains

Each region has 1-3 availability domains (ADs). ADs are isolated data centers.

```bash
# List your region's ADs
oci iam availability-domain list --query 'data[*].name' --output table
```

Example output:
```
+----------------------------+
| name                       |
+----------------------------+
| xxxx:US-ASHBURN-AD-1      |
| xxxx:US-ASHBURN-AD-2      |
| xxxx:US-ASHBURN-AD-3      |
+----------------------------+
```

When launching instances, specify the full AD name:
```bash
--availability-domain "xxxx:US-ASHBURN-AD-1"
```

---

## Error Messages

<details>
<summary><strong>OUT_OF_HOST_CAPACITY</strong></summary>

```
ServiceError: Out of host capacity
```

**Meaning**: No physical servers available in that AD for A1 shape.

**Action**: Try different AD, region, or smaller config.

</details>

<details>
<summary><strong>LimitExceeded</strong></summary>

```
ServiceError: LimitExceeded
```

**Meaning**: You've hit your account's service limit.

**Action**: Check existing A1 instances. Free tier is 4 OCPU + 24GB total.

```bash
oci compute instance list --compartment-id $COMPARTMENT_ID \
  --query 'data[?contains(shape,`A1`)].{name:"display-name",ocpus:"shape-config".ocpus}'
```

</details>

<details>
<summary><strong>InternalError</strong></summary>

```
ServiceError: InternalError
```

**Meaning**: OCI backend issue, often capacity-related.

**Action**: Wait and retry. Usually resolves in minutes.

</details>

---

## Creating Resource Manager Stacks

For use with `monitor-and-deploy.sh`, you need a Resource Manager stack:

<details>
<summary><strong>Creating a stack</strong></summary>

1. **Prepare Terraform configuration** (or use OCI templates)

2. **Create stack via CLI**:
```bash
oci resource-manager stack create \
  --compartment-id $COMPARTMENT_ID \
  --config-source '{"configSourceType":"ZIP_UPLOAD"}' \
  --display-name "my-arm-stack" \
  --terraform-version "1.0.x"
```

3. **Or via Console**:
   - Go to Resource Manager → Stacks → Create Stack
   - Upload your Terraform files or use a template
   - Note the stack OCID

4. **Use with monitor script**:
```bash
./scripts/monitor-and-deploy.sh --stack-id ocid1.ormstack.oc1..xxx
```

</details>

---

## Quick Reference

| Scenario | Solution |
|----------|----------|
| OUT_OF_HOST_CAPACITY | Try different AD or region |
| Need to wait for capacity | Use `monitor-and-deploy.sh` |
| Can't get full 4 OCPU | Try 2 OCPU config |
| Need 4 OCPU urgently | Split across 2 instances |
| Recurring capacity issues | Consider different region |

---

## Next Steps

- Return to [main skill](../SKILL.md)
- See [Networking Guide](./NETWORKING.md) for VCN setup
- See [Troubleshooting Guide](./TROUBLESHOOTING.md) for other issues
