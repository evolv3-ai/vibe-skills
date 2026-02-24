# Claude Skills

**Repository**: https://github.com/evolv3ai/claude-skills
**Owner**: evolv3ai | https://evolv3.ai

Production workflow skills for Claude Code CLI. Each skill guides Claude through a recipe to produce tangible output — not knowledge dumps, but working deliverables.

## Philosophy

- Every skill must produce visible output (files, configurations, deployable projects)
- "The context window is a public good" — only include what Claude doesn't already know
- Follows the official Claude Code plugin spec

## Directory Structure

```
claude-skills/
├── plugins/                                # 6 installable plugins (21 skills)
│   ├── admin/                              # Local machine admin, session discovery
│   │   └── skills/
│   │       ├── admin/
│   │       └── session-scout/
│   ├── cloudflare/                         # Cloudflare DNS CLI
│   │   └── skills/
│   │       └── cloudflare-cli/
│   ├── design-assets/                      # Colour palettes, favicons, icons
│   │   └── skills/
│   ├── dev-tools/                          # Stream Deck, mock APIs, Kanban, pi_agent
│   │   └── skills/
│   │       ├── deckmate/
│   │       ├── mockoon-cli/
│   │       ├── pi-agent-rust/
│   │       └── ralphban/
│   ├── devops/                             # Cloud provisioning + app deployment
│   │   └── skills/
│   │       ├── contabo/
│   │       ├── coolify/
│   │       ├── coolify-cli/
│   │       ├── devops/
│   │       ├── digital-ocean/
│   │       ├── hetzner/
│   │       ├── kasm/
│   │       ├── linode/
│   │       ├── oci/
│   │       ├── openclaw/
│   │       └── vultr/
│   └── integrations/                       # iii engine, SimpleMem, Obsidian RLM
│       └── skills/
│           ├── iii/
│           ├── obsidian-rlm/
│           └── simplemem/
├── .claude-plugin/                         # Marketplace + plugin config
│   ├── marketplace.json
│   └── plugin.json
├── CLAUDE.md                               # This file
├── README.md                               # Public-facing overview
└── LICENSE                                 # MIT
```

## Plugin Anatomy (Anthropic Spec)

Each plugin contains one or more skills, auto-discovered from `skills/`:

```
plugin-name/
├── .claude-plugin/
│   └── plugin.json        # name, description, author
└── skills/
    └── skill-name/
        ├── SKILL.md       # Frontmatter + instructions, under 500 lines
        ├── scripts/       # Executable code (run directly)
        ├── references/    # Docs loaded on demand by Claude
        └── assets/        # Files used in output (templates, images)
```

## Adding a New Plugin

1. Create the plugin directory:
   ```bash
   mkdir -p plugins/my-plugin/{.claude-plugin,skills}
   ```

2. Create `.claude-plugin/plugin.json`:
   ```json
   {
     "name": "my-plugin",
     "description": "What this plugin does.",
     "author": { "name": "evolv3ai", "email": "hello@evolv3.ai" }
   }
   ```

3. Add skills inside `plugins/my-plugin/skills/` (each with SKILL.md)

4. Add an entry to `.claude-plugin/marketplace.json`:
   ```json
   { "name": "my-plugin", "description": "...", "source": "./plugins/my-plugin", "category": "development" }
   ```

5. Update the directory tree in this file and the table in README.md

**Categories**: `development`, `design`, `productivity`, `testing`, `security`, `database`, `monitoring`, `deployment`

## Creating a Skill

Ask Claude: "Create a new skill for [use case]"

Key principle: **every skill must produce something.** If it's just reference material Claude already knows, it doesn't earn a place here.

## Installing Plugins

```bash
# Add marketplace (one-time)
/plugin marketplace add evolv3ai/claude-skills

# Install individual plugins
/plugin install admin@evolv3ai-skills
/plugin install cloudflare@evolv3ai-skills
/plugin install devops@evolv3ai-skills

# Local dev (loads a single plugin without install)
claude --plugin-dir ./plugins/cloudflare
```

After installing, restart Claude Code to load new plugins.

## Quality Bar

Before committing a skill:
- [ ] SKILL.md has valid YAML frontmatter (name + description)
- [ ] Under 500 lines
- [ ] Produces tangible output (not just reference material)
- [ ] Tested by actually using it on a real task
