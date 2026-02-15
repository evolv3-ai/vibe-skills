# Claude Skills

**Repository**: https://github.com/jezweb/claude-skills
**Owner**: Jeremy Dawes (Jez) | Jezweb

Production workflow skills for Claude Code CLI. Each skill guides Claude through a recipe to produce tangible output — not knowledge dumps, but working deliverables.

## Philosophy

- Every skill must produce visible output (files, configurations, deployable projects)
- "The context window is a public good" — only include what Claude doesn't already know
- Follow the Agent Skills spec: https://agentskills.io/specification

## Directory Structure

```
claude-skills/
├── skills/                         # All skills
│   ├── skill-creator/              # Foundation: create new skills (Anthropic official)
│   ├── cloudflare-worker-builder/  # Scaffold Cloudflare Worker projects
│   ├── tailwind-theme-builder/     # Set up Tailwind v4 + shadcn/ui themes
│   ├── color-palette/              # Generate colour palettes from brand hex
│   ├── favicon-gen/                # Generate favicon packages
│   ├── icon-set-generator/         # Generate custom SVG icon sets
│   ├── elevenlabs-agents/          # Build ElevenLabs voice agents
│   ├── mcp-builder/                # Build MCP servers with FastMCP
│   └── memory-manager/             # Audit and restructure CLAUDE.md hierarchy
├── CLAUDE.md                       # This file
├── README.md                       # Public-facing overview
└── LICENSE                         # MIT
```

## Skill Anatomy (Anthropic Spec)

```
skill-name/
├── SKILL.md (required)     # Frontmatter + instructions, under 500 lines
├── scripts/                # Executable code (run directly)
├── references/             # Docs loaded on demand by Claude
└── assets/                 # Files used in output (templates, images)
```

No README.md, no CHANGELOG.md, no rules/ — just what the AI agent needs.

## Creating a Skill

Use the skill-creator skill:

```bash
python3 skills/skill-creator/scripts/init_skill.py my-skill --path skills/
```

Or ask Claude: "Create a new skill for [use case]"

Key principle: **every skill must produce something.** If it's just reference material Claude already knows, it doesn't earn a place here.

## Installing Skills

```bash
# Add marketplace (one-time)
/plugin marketplace add jezweb/claude-skills

# Install all skills
/plugin install jezweb-skills

# Or install individual skill for local dev
/plugin install ./skills/cloudflare-worker-builder
```

After installing, restart Claude Code to load new skills.

## Quality Bar

Before committing a skill:
- [ ] SKILL.md has valid YAML frontmatter (name + description)
- [ ] Under 500 lines
- [ ] Produces tangible output (not just reference material)
- [ ] Passes validation: `python3 skills/skill-creator/scripts/quick_validate.py skills/my-skill`
- [ ] Tested by actually using it on a real task

## Git History

All 105 skills from the v1 era are preserved:
- Tag `v1-final` — the complete 105-skill collection
- Branch `archive/low-priority-skills` — 13 previously archived skills
- Full git history available via `git log v1-final`
