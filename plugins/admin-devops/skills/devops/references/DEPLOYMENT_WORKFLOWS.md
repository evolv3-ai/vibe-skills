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
- Profile gate passed (`test-admin-profile.sh`)

Steps:
1. Retrieve provider API key via `secrets` CLI (e.g., `secrets HCLOUD_TOKEN`).
2. Query SimpleMem for past deployment issues (`memory_query: "Coolify deployment issues"`).
3. Provision server via the provider skill (2+ vCPU, 8GB+ RAM).
4. Install Coolify using `coolify skill`.
5. Configure a tunnel if needed (see `coolify skill` references).
6. Update `profile.servers[]` with server data.
7. Log the operation via `log_admin_event`.
8. Store outcome in SimpleMem.

```env
SERVER_COOLIFY01_ROLE=coolify
SERVER_COOLIFY01_TAGS=paas,docker,prod
```

---

## KASM Workspaces Deployment

Prerequisites:
- Provider skill installed
- `kasm skill` installed
- Profile gate passed (`test-admin-profile.sh`)

Steps:
1. Retrieve provider API key via `secrets` CLI.
2. Query SimpleMem for past deployment issues (`memory_query: "KASM deployment issues"`).
3. Provision server via provider skill (4+ vCPU, 16GB+ RAM).
4. Install KASM using `kasm skill`.
5. Configure a tunnel if needed (route `kasm.yourdomain.com` to port 8443).
6. Update `profile.servers[]` with server data.
7. Log the operation via `log_admin_event`.
8. Store outcome in SimpleMem.

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
1. Pass profile gate and load `profile.servers[]` inventory.
2. Retrieve provider secrets via `secrets` CLI.
3. Query SimpleMem for past infrastructure issues.
4. Provision any missing nodes via provider skills.
5. Install services via `application` skills (coolify, kasm).
6. Configure tunnels for public access.
7. Update `profile.servers[]` with all server data.
8. Log all operations via `log_admin_event`.
9. Store outcomes in SimpleMem.

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
