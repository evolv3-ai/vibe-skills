# Claude Code Skills

[![MIT License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Workflow skills for [Claude Code](https://claude.com/claude-code) that produce tangible output. Each skill guides Claude through a recipe — scaffold a project, generate assets, deploy to production.

## Plugins

| Plugin | Skills | What it produces |
|--------|--------|-----------------|
| **admin** | admin, session-scout | Local machine admin (packages, tools, PATH), AI session discovery |
| **cloudflare** | cloudflare-cli | DNS record CRUD, zone management, scripted Cloudflare workflows |
| **design-assets** | — | Colour palettes, favicon packages, custom SVG icon sets |
| **dev-tools** | deckmate, mockoon-cli, pi-agent-rust, ralphban | Stream Deck profiles, mock REST APIs, Rust agent dev, Kanban task boards |
| **devops** | devops, oci, hetzner, linode, digital-ocean, contabo, vultr, coolify, coolify-cli, kasm, openclaw | Cloud provisioning, app deployment (Coolify, KASM, OpenClaw) |
| **integrations** | iii, simplemem, obsidian-rlm | Cross-language backends, agent memory, large-file Obsidian processing |

## Install

```bash
# Add the marketplace
/plugin marketplace add evolv3ai/claude-skills

# Install individual plugins
/plugin install admin@evolv3ai-skills
/plugin install cloudflare@evolv3ai-skills
/plugin install design-assets@evolv3ai-skills
/plugin install dev-tools@evolv3ai-skills
/plugin install devops@evolv3ai-skills
/plugin install integrations@evolv3ai-skills
```

## Philosophy

**Every skill must produce something.** No knowledge dumps — only workflow recipes that create files, projects, or configurations. Claude's training data handles the rest.

See [CLAUDE.md](CLAUDE.md) for development details.

## License

MIT
