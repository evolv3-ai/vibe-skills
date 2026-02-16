# Claude Code Skills

[![MIT License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Workflow skills for [Claude Code](https://claude.com/claude-code) that produce tangible output. Each skill guides Claude through a recipe — scaffold a project, generate assets, deploy to production.

## Skills

| Skill | What it produces |
|-------|-----------------|
| **[skill-creator](skills/skill-creator)** | New skill directories from template |
| **[cloudflare-worker-builder](skills/cloudflare-worker-builder)** | Deployable Cloudflare Worker projects with Hono + Vite |
| **[vite-flare-starter](skills/vite-flare-starter)** | Full-stack Cloudflare app (React 19, Hono, D1, better-auth, shadcn/ui) |
| **[tailwind-theme-builder](skills/tailwind-theme-builder)** | Themed Tailwind v4 + shadcn/ui setup with dark mode |
| **[color-palette](skills/color-palette)** | Complete colour palettes from a single brand hex |
| **[favicon-gen](skills/favicon-gen)** | Full favicon packages (SVG, ICO, PNG, manifest) |
| **[icon-set-generator](skills/icon-set-generator)** | Custom SVG icon sets with consistent style |
| **[web-design-methodology](skills/web-design-methodology)** | Production HTML/CSS with BEM, responsive, accessibility |
| **[web-design-patterns](skills/web-design-patterns)** | Heroes, cards, CTAs, trust signals, testimonials |
| **[seo-local-business](skills/seo-local-business)** | SEO setup for local businesses (JSON-LD, meta, sitemap) |
| **[google-chat-messages](skills/google-chat-messages)** | Google Chat webhooks (text, rich cards, threads) |
| **[google-apps-script](skills/google-apps-script)** | Google Sheets Apps Script automation (menus, triggers, dialogs) |
| **[elevenlabs-agents](skills/elevenlabs-agents)** | Configured ElevenLabs voice agents |
| **[mcp-builder](skills/mcp-builder)** | MCP servers with FastMCP |
| **[memory-manager](skills/memory-manager)** | Optimised CLAUDE.md memory hierarchy |

## Install

```bash
# Add the marketplace
/plugin marketplace add jezweb/claude-skills

# Install all skills
/plugin install all@jezweb-skills

# Or install by category
/plugin install design@jezweb-skills         # palettes, favicons, icons, web design
/plugin install cloudflare@jezweb-skills     # Workers + vite-flare-starter
/plugin install frontend@jezweb-skills       # Tailwind + shadcn/ui
/plugin install web@jezweb-skills            # web design + SEO
/plugin install integrations@jezweb-skills   # Google Chat, Apps Script
/plugin install ai@jezweb-skills             # ElevenLabs agents
/plugin install mcp@jezweb-skills            # MCP servers
/plugin install development@jezweb-skills    # skill-creator + memory-manager
```

## Create Your Own

```bash
python3 skills/skill-creator/scripts/init_skill.py my-skill --path skills/
```

Follows the [Agent Skills spec](https://agentskills.io/specification).

## Philosophy

**Every skill must produce something.** No knowledge dumps — only workflow recipes that create files, projects, or configurations. Claude's training data handles the rest.

See [CLAUDE.md](CLAUDE.md) for development details.

## License

MIT
