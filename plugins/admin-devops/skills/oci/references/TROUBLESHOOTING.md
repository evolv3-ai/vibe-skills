# OCI Troubleshooting Guide

**Purpose**: Quick solutions for common OCI deployment issues.

---

## Contents
- Quick Diagnostic
- Issue Categories
- CLI & Authentication
- Capacity & Limits
- Networking
- Compute
- General Errors
- Debug Mode
- Getting Help
- Quick Fixes Summary

---

## Quick Diagnostic

Run this first to identify issues:

```bash
oci --version
oci iam availability-domain list
./scripts/check-oci-capacity.sh
```

---

## Issue Categories

- [CLI & Authentication](#cli--authentication)
- [Capacity & Limits](#capacity--limits)
- [Networking](#networking)
- [Compute](#compute)
- [General Errors](#general-errors)

---

## CLI & Authentication

<details>
<summary><strong>oci: command not found</strong></summary>

**Cause**: OCI CLI not installed or not in PATH.

**Solutions**:

1. Install OCI CLI (see `references/INSTALL.md`) and verify:
   ```bash
   oci --version
   ```

2. Or restart terminal to reload PATH:
   ```bash
   source ~/.bashrc  # or ~/.zshrc
   ```

3. Check installation:
   ```bash
   which oci
   oci --version
   ```

See [Installation Guide](./INSTALL.md) for details.

</details>

<details>
<summary><strong>ServiceError: NotAuthenticated</strong></summary>

**Cause**: API key not configured or invalid.

**Checklist**:

1. **Config file exists**:
   ```bash
   cat ~/.oci/config
   ```

2. **API key uploaded to OCI**:
   - OCI Console → Profile → API Keys
   - Verify fingerprint matches config

3. **Key file exists and has correct permissions**:
   ```bash
   ls -la ~/.oci/oci_api_key.pem
   chmod 600 ~/.oci/oci_api_key.pem
   ```

4. **Test authentication**:
   ```bash
   oci iam region list
   ```

See [Configuration Guide](./CONFIG.md) for details.

</details>

<details>
<summary><strong>Config file not found</strong></summary>

**Cause**: No `~/.oci/config` file.

**Fix**:
```bash
oci setup config
```

Follow the prompts to configure credentials.

</details>

<details>
<summary><strong>Private key file not found</strong></summary>

**Cause**: Key file path in config is wrong or file missing.

**Fix**:

1. Check config:
   ```bash
   grep key_file ~/.oci/config
   ```

2. Verify file exists:
   ```bash
   ls -la ~/.oci/oci_api_key.pem
   ```

3. If missing, generate new keys:
   ```bash
   oci setup keys
   ```
   Then upload public key to OCI Console.

</details>

<details>
<summary><strong>Fingerprint mismatch</strong></summary>

**Cause**: Fingerprint in config doesn't match OCI Console.

**Fix**:

1. Get fingerprint from OCI Console:
   - Profile → API Keys → Copy fingerprint

2. Update config:
   ```bash
   nano ~/.oci/config
   # Update fingerprint= line
   ```

</details>

<details>
<summary><strong>Clock skew error</strong></summary>

**Cause**: System time differs significantly from server.

**Fix**:
```bash
# Linux
sudo timedatectl set-ntp true
# or
sudo ntpdate pool.ntp.org

# macOS
sudo sntp -sS time.apple.com
```

</details>

---

## Capacity & Limits

<details>
<summary><strong>OUT_OF_HOST_CAPACITY</strong></summary>

**Cause**: No ARM instances available in the selected AD.

**Solutions**:

1. Check other availability domains:
   ```bash
   ./scripts/check-oci-capacity.sh
   ```

2. Use automated monitoring:
   ```bash
   ./scripts/monitor-and-deploy.sh --stack-id <STACK_OCID>
   ```

3. Try different region

4. Try smaller config (2 OCPU / 12GB)

See [Capacity Guide](./CAPACITY.md) for details.

</details>

<details>
<summary><strong>LimitExceeded / Service limit exceeded</strong></summary>

**Cause**: Account limit reached for A1 instances.

**Check current usage**:
```bash
oci compute instance list \
  --compartment-id $COMPARTMENT_ID \
  --query 'data[?contains(shape,`A1`)].{name:"display-name", ocpus:"shape-config".ocpus, memory:"shape-config"."memory-in-gbs", state:"lifecycle-state"}' \
  --output table
```

**Free tier limits**: 4 OCPUs + 24GB RAM total

**Fix**: Terminate unused A1 instances or reduce new instance size.

</details>

<details>
<summary><strong>TooManyRequests</strong></summary>

**Cause**: API rate limiting.

**Fix**: Wait and retry with exponential backoff:
```bash
sleep 60
# Then retry command
```

For scripts, add delays between API calls.

</details>

---

## Networking

<details>
<summary><strong>Cannot SSH to instance</strong></summary>

**Checklist**:

1. **Instance is running**:
   ```bash
   oci compute instance get --instance-id $INSTANCE_ID \
     --query 'data."lifecycle-state"'
   ```

2. **Has public IP**:
   ```bash
   oci compute instance list-vnics --instance-id $INSTANCE_ID \
     --query 'data[0]."public-ip"'
   ```

3. **Security list allows SSH**:
   ```bash
   oci network security-list get --security-list-id $SL_ID \
     --query 'data."ingress-security-rules"[?contains("tcp-options"."destination-port-range".min, `22`)]'
   ```

4. **Internet gateway exists**:
   ```bash
   oci network internet-gateway list --compartment-id $COMPARTMENT_ID --vcn-id $VCN_ID
   ```

5. **Route table has internet route**:
   ```bash
   oci network route-table get --rt-id $RT_ID --query 'data."route-rules"'
   ```

6. **Correct SSH key**:
   ```bash
   ssh -i ~/.ssh/your_key -o IdentitiesOnly=yes ubuntu@<public-ip>
   ```

7. **Wait after launch** (1-2 minutes for cloud-init)

</details>

<details>
<summary><strong>Instance cannot reach internet</strong></summary>

**Checklist**:

1. **Internet gateway exists**

2. **Route table has 0.0.0.0/0 route to IGW**

3. **Security list allows outbound traffic**:
   ```bash
   oci network security-list get --security-list-id $SL_ID \
     --query 'data."egress-security-rules"'
   ```

**Quick fix** - allow all outbound:
```bash
oci network security-list update \
  --security-list-id $SL_ID \
  --egress-security-rules '[{"destination": "0.0.0.0/0", "protocol": "all"}]' \
  --force
```

</details>

<details>
<summary><strong>CIDR block conflicts</strong></summary>

**Cause**: Overlapping IP ranges between VCNs.

**Fix**: Use non-overlapping CIDR blocks:
```
VCN 1: 10.0.0.0/16
VCN 2: 10.1.0.0/16
VCN 3: 10.2.0.0/16
```

</details>

<details>
<summary><strong>InvalidParameter: Security rule</strong></summary>

**Cause**: Malformed security rule JSON.

**Fix**: Validate JSON syntax:
```bash
echo '[{"source": "0.0.0.0/0", "protocol": "6", "tcpOptions": {"destinationPortRange": {"min": 22, "max": 22}}}]' | jq .
```

Common issues:
- Missing quotes around keys
- Wrong field names (use camelCase)
- Protocol must be string ("6" not 6)

</details>

---

## Compute

<details>
<summary><strong>Shape not available</strong></summary>

**Cause**: Wrong image/shape combination.

**Rule**: ARM64 shape (A1.Flex) requires ARM64 image.

**Find ARM64 Ubuntu images**:
```bash
oci compute image list \
  --compartment-id $TENANCY_OCID \
  --operating-system "Canonical Ubuntu" \
  --shape "VM.Standard.A1.Flex" \
  --query 'data[*].{id:id, name:"display-name"}' \
  --output table
```

</details>

<details>
<summary><strong>Instance stuck in PROVISIONING</strong></summary>

**Cause**: Usually capacity issues or backend delays.

**Check status**:
```bash
oci compute instance get --instance-id $INSTANCE_ID \
  --query 'data.{state:"lifecycle-state", time:"time-created"}'
```

**If stuck > 10 minutes**: Terminate and retry in different AD.

</details>

<details>
<summary><strong>Instance terminated unexpectedly</strong></summary>

**Cause**: Could be capacity reclamation or policy.

**Check termination reason**:
```bash
oci audit event list \
  --compartment-id $COMPARTMENT_ID \
  --start-time $(date -d '1 hour ago' -u +%Y-%m-%dT%H:%M:%SZ) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --query 'data[?contains("event-type", `Terminate`)].{type:"event-type", time:"event-time", source:"event-source"}'
```

</details>

<details>
<summary><strong>Cannot attach block volume</strong></summary>

**Cause**: Volume and instance must be in same AD.

**Check**:
```bash
# Instance AD
oci compute instance get --instance-id $INSTANCE_ID \
  --query 'data."availability-domain"'

# Volume AD
oci bv volume get --volume-id $VOLUME_ID \
  --query 'data."availability-domain"'
```

</details>

---

## General Errors

<details>
<summary><strong>InvalidParameter</strong></summary>

**Cause**: Required parameter missing or invalid format.

**Debug**:
```bash
# Add --debug to see full request/response
oci compute instance launch --debug ...
```

Check:
- OCIDs are complete (start with `ocid1.`)
- Correct parameter names
- Valid JSON format for complex params

</details>

<details>
<summary><strong>NotAuthorizedOrNotFound</strong></summary>

**Cause**: Resource doesn't exist or no permission.

**Check**:

1. Resource exists:
   ```bash
   oci <service> <resource> get --<resource>-id <OCID>
   ```

2. Correct compartment:
   ```bash
   oci <service> <resource> list --compartment-id $COMPARTMENT_ID
   ```

3. IAM policies allow access

</details>

<details>
<summary><strong>InternalError</strong></summary>

**Cause**: OCI backend issue.

**Fix**: Wait 1-5 minutes and retry. Usually transient.

If persistent, check [OCI Status](https://ocistatus.oraclecloud.com/).

</details>

<details>
<summary><strong>Timeout errors</strong></summary>

**Cause**: Operation taking too long.

**Fix**:

1. Increase timeout:
   ```bash
   oci compute instance launch --wait-for-state RUNNING --wait-interval-seconds 30 --max-wait-seconds 600
   ```

2. Don't wait, poll separately:
   ```bash
   # Launch without wait
   INSTANCE_ID=$(oci compute instance launch ... --query 'data.id' --raw-output)

   # Poll for status
   while true; do
     STATE=$(oci compute instance get --instance-id $INSTANCE_ID --query 'data."lifecycle-state"' --raw-output)
     [[ "$STATE" == "RUNNING" ]] && break
     sleep 30
   done
   ```

</details>

---

## Debug Mode

For detailed troubleshooting, enable debug output:

```bash
# Full debug (very verbose)
oci --debug compute instance list

# Log to file
oci --debug compute instance list 2>&1 | tee oci-debug.log
```

---

## Getting Help

1. **Check OCI Status**: https://ocistatus.oraclecloud.com/
2. **OCI Documentation**: https://docs.oracle.com/en-us/iaas/
3. **OCI CLI Reference**: https://docs.oracle.com/en-us/iaas/tools/oci-cli/latest/
4. **Support Request**: OCI Console → Help → Create Support Request

---

## Quick Fixes Summary

| Error | Quick Fix |
|-------|-----------|
| Command not found | Install OCI CLI (`references/INSTALL.md`) |
| NotAuthenticated | Check `~/.oci/config`, upload API key |
| OUT_OF_HOST_CAPACITY | Try different AD/region |
| LimitExceeded | Check existing A1 instances |
| Cannot SSH | Check security list, public IP, IGW |
| Shape not available | Use ARM64 image with ARM64 shape |
| InternalError | Wait and retry |
