# Claude Code Slash Commands

This directory contains **orphan commands** - specialized commands for managing the claude-skills repository itself. These are niche tools not needed by most users.

## ⚠️ Command Discovery: Plugin vs Symlinks (2026-01-11)

**Important Discovery**: Claude Code discovers slash commands from `~/.claude/commands/` directory, NOT from plugin bundles. Plugin bundles provide skills/agents/rules, but commands need symlinks.

Most slash commands have been moved into their appropriate skills for organization, but still need symlinks:

| Command | Skill Location | Symlink Required |
|---------|----------------|------------------|
| `/explore-idea` | `project-workflow/commands/` | Yes |
| `/plan-project` | `project-workflow/commands/` | Yes |
| `/plan-feature` | `project-workflow/commands/` | Yes |
| `/wrap-session` | `project-workflow/commands/` | Yes |
| `/continue-session` | `project-workflow/commands/` | Yes |
| `/workflow` | `project-workflow/commands/` | Yes |
| `/release` | `project-workflow/commands/` | Yes |
| `/brief` | `project-workflow/commands/` | Yes |
| `/reflect` | `project-workflow/commands/` | Yes |
| `/deploy` | `cloudflare-worker-base/commands/` | Yes |
| `/docs` | `docs-workflow/commands/` | Yes |
| `/docs-init` | `docs-workflow/commands/` | Yes |
| `/docs-update` | `docs-workflow/commands/` | Yes |
| `/docs-claude` | `docs-workflow/commands/` | Yes |

### Creating Symlinks

```bash
# docs-workflow commands
ln -sf /path/to/claude-skills/skills/docs-workflow/commands/docs.md ~/.claude/commands/
ln -sf /path/to/claude-skills/skills/docs-workflow/commands/docs-init.md ~/.claude/commands/
ln -sf /path/to/claude-skills/skills/docs-workflow/commands/docs-update.md ~/.claude/commands/
ln -sf /path/to/claude-skills/skills/docs-workflow/commands/docs-claude.md ~/.claude/commands/

# project-workflow commands
ln -sf /path/to/claude-skills/skills/project-workflow/commands/brief.md ~/.claude/commands/
ln -sf /path/to/claude-skills/skills/project-workflow/commands/reflect.md ~/.claude/commands/
# ... etc for other commands

# cloudflare-worker-base commands
ln -sf /path/to/claude-skills/skills/cloudflare-worker-base/commands/deploy.md ~/.claude/commands/
```

## Orphan Commands (This Directory)

These commands are specific to the claude-skills repository and not bundled with any skill:

### `/create-skill`

**Purpose**: Scaffold a new Claude Code skill from template

**Usage**: `/create-skill my-skill-name`

**What it does**:
1. Validates skill name (lowercase-hyphen-case, max 40 chars)
2. Asks about skill type (Cloudflare/AI/Frontend/Auth/Database/Tooling/Generic)
3. Copies `templates/skill-skeleton/` to `skills/<name>/`
4. Auto-populates name and dates in SKILL.md
5. Applies type-specific customizations
6. Creates README.md with auto-trigger keywords
7. Runs metadata check
8. Installs skill

**When to use**: Creating a new skill from scratch

---

### `/review-skill`

**Purpose**: Quality review and audit of an existing skill

**Usage**: `/review-skill skill-name`

**What it does**:
1. Checks SKILL.md structure and metadata
2. Validates package versions against latest
3. Reviews error documentation
4. Checks template completeness
5. Suggests improvements

**When to use**: Before publishing a skill update

---

### `/audit`

**Purpose**: Multi-agent audit swarm for parallel skill verification

**Usage**: `/audit` or `/audit skill-name`

**What it does**:
1. Launches parallel agents to audit multiple skills
2. Checks versions, metadata, content quality
3. Generates consolidated report

**When to use**: Quarterly maintenance, bulk skill auditing

---

### `/deep-audit`

**Purpose**: Deep content validation against official documentation

**Usage**: `/deep-audit skill-name`

**What it does**:
1. Fetches official documentation for the skill's technology
2. Compares patterns and versions
3. Identifies knowledge gaps or outdated content
4. Suggests corrections and updates

**When to use**: Major version updates, accuracy verification

---

## Installation

For orphan commands, copy to your `.claude/commands/` directory:

```bash
cp commands/create-skill.md ~/.claude/commands/
cp commands/review-skill.md ~/.claude/commands/
cp commands/audit.md ~/.claude/commands/
cp commands/deep-audit.md ~/.claude/commands/
```

## Related Skills

| Skill | Description | Commands Included |
|-------|-------------|-------------------|
| `project-workflow` | Project lifecycle management | 9 commands (explore-idea, plan-project, etc.) |
| `docs-workflow` | Documentation lifecycle | 4 commands (docs, docs-init, docs-update, docs-claude) |
| `cloudflare-worker-base` | Cloudflare Workers setup | 1 command (deploy) |

### Setup for Full Command Access

Skills provide context (templates, rules, agents), but commands need symlinks:

```bash
# 1. Clone the repo (if not already)
git clone https://github.com/jezweb/claude-skills ~/Documents/claude-skills

# 2. Create symlinks for all skill commands
cd ~/.claude/commands

# docs-workflow
for cmd in docs docs-init docs-update docs-claude; do
  ln -sf ~/Documents/claude-skills/skills/docs-workflow/commands/${cmd}.md .
done

# project-workflow
for cmd in brief reflect workflow explore-idea plan-project plan-feature wrap-session continue-session release; do
  ln -sf ~/Documents/claude-skills/skills/project-workflow/commands/${cmd}.md .
done

# cloudflare-worker-base
ln -sf ~/Documents/claude-skills/skills/cloudflare-worker-base/commands/deploy.md .
```

---

**Version**: 6.0.0
**Last Updated**: 2026-01-11
**Author**: Jeremy Dawes | Jezweb
