# OCI CLI Configuration Guide

**Purpose**: Configure OCI CLI credentials and authentication.
**Prerequisites**: [OCI CLI Installed](./INSTALL.md)
**Time**: 5-10 minutes
**Next Step**: Return to [SKILL.md](../SKILL.md) for deployment

---

## Contents
- Quick Check
- Configuration Methods
- Finding Your OCIDs
- Multiple Profiles
- Verify Configuration
- Troubleshooting
- Environment Variables (Alternative)
- Instance Principal Authentication
- Security Best Practices
- Next Steps
- Official Resources

---

## Quick Check

First, verify if OCI CLI is already configured:

```bash
oci iam availability-domain list
```

If you see availability domains listed, you're already configured. Return to [main skill](../SKILL.md).

---

## Configuration Methods

### Method 1: Interactive Setup (Recommended)

```bash
oci setup config
```

This wizard will prompt you for:

| Prompt | Value | Where to Find |
|--------|-------|---------------|
| Config file location | `~/.oci/config` (default) | Press Enter |
| User OCID | `ocid1.user.oc1..xxx` | OCI Console → Profile → My Profile |
| Tenancy OCID | `ocid1.tenancy.oc1..xxx` | OCI Console → Profile → Tenancy |
| Region | e.g., `us-ashburn-1` | OCI Console → top bar |
| Generate API key? | `Y` (yes) | Creates new key pair |
| Key file location | `~/.oci/oci_api_key.pem` | Press Enter |

After completion, **upload your public key to OCI**:
```bash
cat ~/.oci/oci_api_key_public.pem
```

Copy the output and add it in: **OCI Console → Profile → API Keys → Add API Key → Paste Public Key**

---

### Method 2: Manual Configuration

<details>
<summary><strong>Create config file manually</strong></summary>

Create `~/.oci/config`:

```ini
[DEFAULT]
user=ocid1.user.oc1..aaaaaaaaxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
fingerprint=xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx
tenancy=ocid1.tenancy.oc1..aaaaaaaaxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
region=us-ashburn-1
key_file=~/.oci/oci_api_key.pem
```

Set proper permissions:
```bash
chmod 600 ~/.oci/config
chmod 600 ~/.oci/oci_api_key.pem
```

</details>

---

## Finding Your OCIDs

<details>
<summary><strong>🔑 User OCID</strong></summary>

1. Log in to [OCI Console](https://cloud.oracle.com)
2. Click Profile icon (top-right) → **My Profile**
3. Under **User Information**, copy the **OCID**

Format: `ocid1.user.oc1..aaaaaaaxxxxxxxxx`

</details>

<details>
<summary><strong>🏢 Tenancy OCID</strong></summary>

1. Log in to [OCI Console](https://cloud.oracle.com)
2. Click Profile icon (top-right) → **Tenancy: [name]**
3. Under **Tenancy Information**, copy the **OCID**

Format: `ocid1.tenancy.oc1..aaaaaaaxxxxxxxxx`

</details>

<details>
<summary><strong>🌍 Region Identifier</strong></summary>

1. Look at the top bar of OCI Console
2. Click the region dropdown
3. Note the region identifier (not the friendly name)

Common regions:
| Friendly Name | Identifier |
|--------------|------------|
| US East (Ashburn) | `us-ashburn-1` |
| US West (Phoenix) | `us-phoenix-1` |
| Canada (Toronto) | `ca-toronto-1` |
| Canada (Montreal) | `ca-montreal-1` |
| UK (London) | `uk-london-1` |
| Germany (Frankfurt) | `eu-frankfurt-1` |

[Full region list](https://docs.oracle.com/en-us/iaas/Content/General/Concepts/regions.htm)

</details>

<details>
<summary><strong>🔐 API Key Fingerprint</strong></summary>

After uploading your public key:

1. OCI Console → Profile → **API Keys**
2. Find your key in the list
3. Copy the **Fingerprint**

Format: `xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx`

</details>

---

## Multiple Profiles

Use named profiles for multiple accounts or environments:

```ini
[DEFAULT]
user=ocid1.user.oc1..default_user
tenancy=ocid1.tenancy.oc1..default_tenancy
region=us-ashburn-1
fingerprint=xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx
key_file=~/.oci/default_api_key.pem

[PRODUCTION]
user=ocid1.user.oc1..prod_user
tenancy=ocid1.tenancy.oc1..prod_tenancy
region=us-phoenix-1
fingerprint=yy:yy:yy:yy:yy:yy:yy:yy:yy:yy:yy:yy:yy:yy:yy:yy
key_file=~/.oci/prod_api_key.pem

[DANIEL]
user=ocid1.user.oc1..daniel_user
tenancy=ocid1.tenancy.oc1..daniel_tenancy
region=ca-montreal-1
fingerprint=zz:zz:zz:zz:zz:zz:zz:zz:zz:zz:zz:zz:zz:zz:zz:zz
key_file=~/.oci/daniel_api_key.pem
```

Use a specific profile:
```bash
oci iam region list --profile PRODUCTION
```

---

## Verify Configuration

```bash
# Test default profile
oci iam availability-domain list

# Test specific profile
oci iam availability-domain list --profile DANIEL

# List regions accessible to your account
oci iam region list
```

Expected output: JSON with availability domains or regions.

---

## Troubleshooting

<details>
<summary><strong>NotAuthenticated Error</strong></summary>

**Error**: `ServiceError: NotAuthenticated`

**Causes & Fixes**:

1. **API key not uploaded to OCI**
   ```bash
   # Show public key to upload
   cat ~/.oci/oci_api_key_public.pem
   ```
   Add in: OCI Console → Profile → API Keys → Add API Key

2. **Wrong fingerprint in config**
   - Compare fingerprint in `~/.oci/config` with OCI Console

3. **Clock skew**
   ```bash
   # Check system time
   date
   # Sync time (Linux)
   sudo ntpdate pool.ntp.org
   ```

</details>

<details>
<summary><strong>Config file not found</strong></summary>

**Error**: `Could not find config file at ~/.oci/config`

**Fix**:
```bash
# Create directory
mkdir -p ~/.oci

# Run setup
oci setup config
```

</details>

<details>
<summary><strong>Private key file not found</strong></summary>

**Error**: `Could not find private key file`

**Fix**:
```bash
# Check if key exists
ls -la ~/.oci/

# If missing, generate new key pair
oci setup keys

# Then upload public key to OCI Console
```

</details>

<details>
<summary><strong>Permission denied on key file</strong></summary>

**Error**: `Permission denied` or `key file permissions too open`

**Fix**:
```bash
chmod 600 ~/.oci/config
chmod 600 ~/.oci/oci_api_key.pem
```

</details>

<details>
<summary><strong>Invalid region</strong></summary>

**Error**: `region not in valid_regions`

**Fix**:
```bash
# List valid regions
oci iam region list

# Use exact region identifier in config
region=us-ashburn-1  # correct
region=US-Ashburn-1  # wrong (case sensitive)
```

</details>

---

## Environment Variables (Alternative)

Instead of config file, use environment variables:

```bash
export OCI_CLI_USER=ocid1.user.oc1..xxx
export OCI_CLI_TENANCY=ocid1.tenancy.oc1..xxx
export OCI_CLI_FINGERPRINT=xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx
export OCI_CLI_KEY_FILE=~/.oci/oci_api_key.pem
export OCI_CLI_REGION=us-ashburn-1
```

---

## Instance Principal Authentication

For scripts running on OCI compute instances:

<details>
<summary><strong>Set up Instance Principal</strong></summary>

1. Create a Dynamic Group:
   ```
   OCI Console → Identity → Dynamic Groups → Create
   Name: MyInstanceGroup
   Rule: instance.compartment.id = 'ocid1.compartment.oc1..xxx'
   ```

2. Create Policy:
   ```
   Allow dynamic-group MyInstanceGroup to manage all-resources in compartment MyCompartment
   ```

3. Use in CLI:
   ```bash
   oci --auth instance_principal iam region list
   ```

No config file needed when running on the instance.

</details>

---

## Security Best Practices

- **Never commit** `~/.oci/config` or private keys to git
- **Rotate API keys** periodically (OCI Console → API Keys → Add/Remove)
- **Use instance principals** when running on OCI compute
- **Limit permissions** with IAM policies (least privilege)
- **Use separate profiles** for dev/staging/prod

---

## Next Steps

Once configured, return to the [main skill](../SKILL.md) for deployment instructions.

---

## Official Resources

- [OCI CLI Configuration](https://docs.oracle.com/en-us/iaas/Content/API/SDKDocs/cliconfigure.htm)
- [API Key Management](https://docs.oracle.com/en-us/iaas/Content/Identity/Tasks/managingcredentials.htm)
- [Instance Principal Authentication](https://docs.oracle.com/en-us/iaas/Content/Identity/Tasks/callingservicesfrominstances.htm)
