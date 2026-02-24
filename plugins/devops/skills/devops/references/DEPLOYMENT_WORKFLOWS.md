# Deployment Workflows

## Contents
- Coolify deployment
- KASM Workspaces deployment
- Multi‑server deployment
- Cost comparison (snapshot)

---

## Coolify Deployment

Prerequisites:
- Provider skill installed (e.g., `oci`)
- `coolify` skill installed

Steps:
1. Provision server via the provider skill (2+ vCPU, 8GB+ RAM).
2. Add server to inventory with `ROLE=coolify`.
3. Install Coolify using `coolify skill`.
4. Configure a tunnel if needed (see `coolify skill` references).
5. Update inventory:

```env
SERVER_COOLIFY01_ROLE=coolify
SERVER_COOLIFY01_TAGS=paas,docker,prod
```

---

## KASM Workspaces Deployment

Prerequisites:
- Provider skill installed
- `kasm skill` installed

Steps:
1. Provision server via provider skill (4+ vCPU, 16GB+ RAM).
2. Add server to inventory with `ROLE=kasm`.
3. Install KASM using `kasm skill`.
4. Configure a tunnel if needed (route `kasm.yourdomain.com` to port 8443).
5. Update inventory:

```env
SERVER_KASM01_ROLE=kasm
SERVER_KASM01_TAGS=vdi,workspaces,secure
```

---

## Multi‑Server Deployment

Recommended architecture:

| Server | Role | Provider | Resources |
|--------|------|----------|-----------|
| COOLIFY01 | coolify | OCI | 2 OCPU, 12GB |
| KASM01 | kasm | Hetzner | 4 vCPU, 16GB |
| DB01 | database | OCI | 2 OCPU, 12GB |

Steps:
1. Check inventory for existing servers.
2. Provision any missing nodes via provider skills.
3. Install services via `application` skills.
4. Configure tunnels for public access.
5. Update inventory with full server blocks.

Cost optimization ideas:
- Use OCI Free Tier for ARM64 VMs.
- Use Contabo for extra capacity when OCI is full.
- Use Hetzner for EU presence.

---

## Cost Comparison (snapshot)

Prices below are snapshots and may change; verify in provider consoles.

| Provider | Coolify/KASM (4-8GB) | Monthly | Notes |
|----------|----------------------|---------|-------|
| OCI Free Tier | 4 OCPU, 24GB | $0 | Best value (capacity limited) |
| Contabo | 6 vCPU, 18GB | EUR8 | Best paid option |
| Hetzner | 4 vCPU ARM, 8GB | EUR8 | ARM (EU only) |
| DigitalOcean | 4 vCPU, 8GB | $48 | Kasm auto‑scaling |
| Vultr | 4 vCPU, 8GB | $48 | Global NVMe |
| Linode | 4 vCPU, 8GB | $48 | Akamai network |
