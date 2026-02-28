# vibe-skills

**Owner**: [evolv3ai](https://evolv3.ai) | hello@evolv3.ai
**License**: MIT

Production workflow skills for [Claude Code](https://claude.ai/code). Two plugins covering local admin, remote infrastructure, and standalone utilities.

## Plugins

### admin-devops

Local machine administration, remote infrastructure provisioning, and application deployment. Profile-aware with 8 agents and 8 slash commands.

| Skill | Purpose |
|---|---|
| admin | Local admin — profiles, tools, MCP servers, logging, vault |
| devops | Remote infra orchestration, server inventory |
| oci | Oracle Cloud Infrastructure (ARM64, Always Free tier) |
| hetzner | Hetzner Cloud (ARM64 + x86) |
| contabo | Contabo VPS (x86) |
| digital-ocean | DigitalOcean Droplets (x86) |
| vultr | Vultr Cloud Compute (x86) |
| linode | Linode/Akamai Cloud (x86) |
| coolify | Self-hosted PaaS (Nixpacks, Docker, Compose) |
| coolify-cli | Coolify CLI reference and workflows |
| kasm | Container-based VDI (browser streaming) |
| openclaw | AI gateway (multi-LLM, multi-channel messaging) |
| cloudflare-cli | Cloudflare DNS management |

**Commands**: `/install`, `/setup-profile`, `/mcp-bot`, `/skills-bot`, `/troubleshoot`, `/provision`, `/deploy`, `/server-status`

**Agents**: profile-validator, docs-agent, verify-agent, tool-installer, mcp-bot, ops-bot, server-provisioner, deployment-coordinator

### tools

Standalone utility skills that support operations.

| Skill | Purpose |
|---|---|
| simplemem | Semantic long-term memory via MCP |
| session-scout | Discover recent AI coding sessions |
| pi-agent-rust | pi_agent_rust development workflows |
| iii | Cross-language backend engine (WebSocket) |

## Install

```bash
# Add marketplace
/plugin marketplace add evolv3-ai/vibe-skills

# Install plugins
/plugin install admin-devops@vibe-skills
/plugin install tools@vibe-skills
```

## Local Development

```bash
# Load a single plugin for testing
claude --plugin-dir ./plugins/admin-devops
claude --plugin-dir ./plugins/tools
```

## Philosophy

- Every skill produces visible output — files, configs, deployments
- "The context window is a public good" — only include what Claude doesn't already know
- Follows the official Claude Code plugin spec
