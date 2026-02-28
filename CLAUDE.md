# CLAUDE.md — vibe-skills

**Repository**: https://github.com/evolv3-ai/vibe-skills
**Owner**: evolv3ai | https://evolv3.ai

This repo is the development workspace for evolv3ai's Claude Code agent skills. It contains two plugins — `admin-devops` (operational skills) and `tools` (standalone utilities).

## Directory Structure

```
vibe-skills/
├── plugins/
│   ├── admin-devops/              # Local admin + remote infra + app deployment
│   │   ├── .claude-plugin/
│   │   │   └── plugin.json
│   │   ├── commands/              # 8 slash commands
│   │   ├── agents/                # 8 agent definitions
│   │   └── skills/                # 13 skills
│   │       ├── admin/             # Local machine admin, profiles, MCP, logging
│   │       ├── devops/            # Remote infra orchestration, server inventory
│   │       ├── oci/               # Oracle Cloud (ARM64, Always Free)
│   │       ├── hetzner/           # Hetzner Cloud (ARM64 + x86)
│   │       ├── contabo/           # Contabo VPS (x86)
│   │       ├── digital-ocean/     # DigitalOcean (x86)
│   │       ├── vultr/             # Vultr Cloud (x86)
│   │       ├── linode/            # Linode/Akamai (x86)
│   │       ├── coolify/           # Self-hosted PaaS deployment
│   │       ├── coolify-cli/       # Coolify CLI reference
│   │       ├── kasm/              # Container-based VDI
│   │       ├── openclaw/          # AI gateway (multi-LLM, multi-channel)
│   │       └── cloudflare-cli/    # Cloudflare DNS management
│   └── tools/                     # Standalone utilities
│       ├── .claude-plugin/
│       │   └── plugin.json
│       └── skills/                # 4 skills
│           ├── simplemem/         # Semantic long-term memory via MCP
│           ├── session-scout/     # Discover recent AI sessions
│           ├── pi-agent-rust/     # pi_agent_rust development workflows
│           └── iii/               # Cross-language backend engine
├── .claude-plugin/
│   ├── plugin.json
│   └── marketplace.json
└── .gitignore
```

## Skill Anatomy

Every skill follows the Anthropic plugin spec:

```
skill-name/
├── SKILL.md           # Frontmatter (name, description) + instructions
├── scripts/           # Executable scripts (bash, PowerShell, TypeScript)
├── references/        # Docs loaded on demand by Claude
└── assets/            # Templates, configs, env files
```

### Rules

- `SKILL.md` is the only required file — must have valid YAML frontmatter
- Keep SKILL.md under 500 lines — "the context window is a public good"
- Every skill must produce tangible output (files, configs, deployments), not just reference material
- Scripts must be executable (`chmod +x`)
- Cross-platform scripts: provide both `.sh` and `.ps1` variants

## Adding a New Skill

1. Create the skill directory under the appropriate plugin:
   ```bash
   mkdir -p plugins/admin-devops/skills/new-skill/{scripts,references,assets}
   ```

2. Create `SKILL.md` with frontmatter:
   ```yaml
   ---
   name: new-skill
   description: What this skill does in one sentence.
   ---
   ```

3. Add instructions, scripts, and references as needed.

4. Test locally:
   ```bash
   claude --plugin-dir ./plugins/admin-devops
   ```

## Adding a Slash Command

Create a markdown file in the plugin's `commands/` directory:

```bash
# plugins/admin-devops/commands/my-command.md
```

Commands are auto-discovered by Claude Code from the `commands/` directory.

## Adding an Agent

Create a markdown file in the plugin's `agents/` directory with frontmatter:

```yaml
---
name: my-agent
description: When to use this agent
model: sonnet  # or haiku, opus
tools:
  - Read
  - Bash
  - Grep
---
```

## Testing Skills

- **Local dev**: `claude --plugin-dir ./plugins/admin-devops`
- **Both plugins**: run two sessions or install via marketplace
- **After changes**: restart Claude Code to reload plugins

## Installing from Marketplace

```bash
# Add marketplace (one-time)
/plugin marketplace add evolv3-ai/vibe-skills

# Install plugins
/plugin install admin-devops@vibe-skills
/plugin install tools@vibe-skills
```

## Quality Checklist

Before committing a skill:
- [ ] SKILL.md has valid YAML frontmatter (name + description)
- [ ] Under 500 lines
- [ ] Produces tangible output
- [ ] Tested on a real task
- [ ] Scripts are executable
- [ ] No hardcoded paths (use profile resolution)
