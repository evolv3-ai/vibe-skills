# Plugin Installation Guide

Complete guide to installing, testing, and managing Claude Code skills using the plugin system.

**Last Updated**: 2026-02-02

---

## Quick Reference

| Action | Command |
|--------|---------|
| Add marketplace | `/plugin marketplace add jezweb/claude-skills` |
| Install plugin bundle | `/plugin install cloudflare@jezweb-skills` |
| Install local skill | `/plugin install ./skills/skill-name` |
| Update marketplace | `/plugin marketplace update jezweb-skills` |
| List installed | `/plugin list` |

---

## Installation Methods

### Method 1: Marketplace (Recommended)

For using published skills:

```bash
# Add the marketplace (one-time setup)
/plugin marketplace add jezweb/claude-skills

# Install a plugin bundle (e.g., all Cloudflare skills)
/plugin install cloudflare@jezweb-skills

# Or install by full marketplace URL
/plugin marketplace add https://github.com/jezweb/claude-skills
/plugin install cloudflare-worker-base@jezweb-skills
```

**Available Plugin Bundles:**

| Bundle | Skills | Description |
|--------|--------|-------------|
| `cloudflare` | 17 | Workers, D1, R2, KV, Agents, Durable Objects |
| `ai` | 13 | AI SDK, OpenAI, Claude, Gemini |
| `frontend` | 15 | Tailwind, React, TanStack, Zustand |
| `auth` | 5 | Clerk, Better Auth, OAuth |
| `database` | 6 | Drizzle, Neon, Vercel KV/Blob |
| `mcp` | 5 | MCP servers, FastMCP, TypeScript MCP |
| `project` | 8 | Planning, workflow, session management |

### Method 2: Local Development

For testing skills you're developing:

```bash
# Clone the repository
git clone https://github.com/jezweb/claude-skills.git
cd claude-skills

# Install a specific skill for testing
/plugin install ./skills/cloudflare-worker-base

# Or add the local repo as a marketplace
/plugin marketplace add ./
/plugin install cloudflare
```

---

## After Installation: Restart Required

**Important**: After installing or updating plugins, you must restart Claude Code for changes to take effect.

```bash
# Exit Claude Code
exit

# Restart Claude Code
claude
```

**Why?** Skills are loaded at startup. New skills won't be discoverable until the next session.

---

## Local Testing Workflow

When developing or modifying skills:

### 1. Make Changes

Edit the skill files:
```
skills/my-skill/
├── SKILL.md      # Main skill documentation
├── README.md     # Keywords for auto-discovery
├── templates/    # Code templates
└── references/   # Reference docs
```

### 2. Install Locally

```bash
/plugin install ./skills/my-skill
```

### 3. Restart Claude Code

```bash
exit
claude
```

### 4. Test Discovery

Ask Claude something that should trigger your skill:
```
"Set up a [technology your skill covers]"
```

Claude should suggest using your skill.

### 5. Iterate

If changes don't appear:
1. Verify SKILL.md has valid YAML frontmatter
2. Check README.md has trigger keywords
3. Reinstall: `/plugin install ./skills/my-skill`
4. Restart Claude Code again

---

## Plugin vs Skill vs Marketplace

Understanding the hierarchy:

```
Marketplace (jezweb-skills)
└── Plugin Bundles (cloudflare, ai, frontend...)
    └── Individual Skills (cloudflare-worker-base, cloudflare-d1...)
```

| Term | Description | Example |
|------|-------------|---------|
| **Marketplace** | Collection of plugins from a source | `jezweb-skills` |
| **Plugin** | Bundle of related skills | `cloudflare` (17 skills) |
| **Skill** | Single capability/technology | `cloudflare-d1` |

---

## Cache Behavior

Plugins are cached locally after installation:

```
~/.claude/plugins/cache/jezweb-skills/
├── skills/
│   ├── cloudflare-worker-base/
│   ├── cloudflare-d1/
│   └── ...
└── marketplace.json
```

### Updating Cache

To get the latest versions:

```bash
# Update marketplace metadata
/plugin marketplace update jezweb-skills

# Reinstall specific plugin to refresh
/plugin install cloudflare@jezweb-skills --force
```

### Clearing Cache

If you encounter issues:

```bash
# Remove and re-add marketplace
/plugin marketplace remove jezweb-skills
/plugin marketplace add jezweb/claude-skills
/plugin install cloudflare@jezweb-skills
```

---

## Verifying Installation

### Check Installed Plugins

```bash
/plugin list
```

### Check Skill Discovery

Ask Claude:
```
"What skills do you have for Cloudflare?"
```

Claude should list installed Cloudflare skills.

### Check Specific Skill

```
"Do you have the cloudflare-d1 skill?"
```

---

## Common Installation Scenarios

### Scenario 1: Fresh Setup

```bash
# 1. Add marketplace
/plugin marketplace add jezweb/claude-skills

# 2. Install what you need
/plugin install cloudflare@jezweb-skills
/plugin install ai@jezweb-skills

# 3. Restart
exit
claude

# 4. Verify
"What Cloudflare skills do you have?"
```

### Scenario 2: Contributing a New Skill

```bash
# 1. Clone repo
git clone https://github.com/jezweb/claude-skills.git
cd claude-skills

# 2. Create skill from template
cp -r templates/skill-skeleton/ skills/my-new-skill/

# 3. Edit SKILL.md and README.md

# 4. Test locally
/plugin install ./skills/my-new-skill
exit
claude

# 5. Verify it works
"Help me with [my-new-skill topic]"

# 6. Commit and push
git add skills/my-new-skill
git commit -m "Add my-new-skill"
git push
```

### Scenario 3: Updating After Upstream Changes

```bash
# 1. Pull latest
cd ~/Documents/claude-skills
git pull

# 2. Update marketplace
/plugin marketplace update jezweb-skills

# 3. Reinstall changed plugins
/plugin install cloudflare@jezweb-skills --force

# 4. Restart
exit
claude
```

---

## Plugin Manifest Structure

Each skill can have a plugin manifest at `.claude-plugin/plugin.json`:

```json
{
  "name": "cloudflare-worker-base",
  "version": "1.0.0",
  "description": "Foundation for Cloudflare Workers",
  "skills": ["cloudflare-worker-base"],
  "agents": ["cloudflare-deploy", "worker-scaffold"]
}
```

**Generating Manifests:**

```bash
# Generate for all skills
./scripts/generate-plugin-manifests.sh

# Generate for specific skill
./scripts/generate-plugin-manifests.sh cloudflare-worker-base
```

---

## Troubleshooting Installation

| Problem | Solution |
|---------|----------|
| Skill not found after install | Restart Claude Code |
| "Marketplace not found" | Re-add: `/plugin marketplace add jezweb/claude-skills` |
| Changes not appearing | Clear cache, reinstall, restart |
| Local skill not loading | Check YAML frontmatter is valid |
| Plugin conflicts | Remove and reinstall the plugin |

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for detailed solutions.

---

## Related Documentation

- [MARKETPLACE.md](MARKETPLACE.md) - Full marketplace details
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Common issues and fixes
- [../CONTRIBUTING.md](../CONTRIBUTING.md) - Creating new skills
- [../ONE_PAGE_CHECKLIST.md](../ONE_PAGE_CHECKLIST.md) - Quality checklist

---

**Maintainer**: Jeremy Dawes | Jezweb
