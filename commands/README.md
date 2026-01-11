# Claude Code Slash Commands

This directory contains **orphan commands** - specialized commands for managing the claude-skills repository itself. These are niche tools not needed by most users.

## ⚠️ Command Reorganization (2026-01-11)

Most slash commands have been moved into their appropriate skills:

| Command | Now In | Installation |
|---------|--------|--------------|
| `/explore-idea` | `project-workflow` | `/plugin install project-workflow@claude-skills` |
| `/plan-project` | `project-workflow` | `/plugin install project-workflow@claude-skills` |
| `/plan-feature` | `project-workflow` | `/plugin install project-workflow@claude-skills` |
| `/wrap-session` | `project-workflow` | `/plugin install project-workflow@claude-skills` |
| `/continue-session` | `project-workflow` | `/plugin install project-workflow@claude-skills` |
| `/workflow` | `project-workflow` | `/plugin install project-workflow@claude-skills` |
| `/release` | `project-workflow` | `/plugin install project-workflow@claude-skills` |
| `/brief` | `project-workflow` | `/plugin install project-workflow@claude-skills` |
| `/reflect` | `project-workflow` | `/plugin install project-workflow@claude-skills` |
| `/deploy` | `cloudflare-worker-base` | `/plugin install cloudflare-worker-base@claude-skills` |
| `/docs` | `docs-workflow` | `/plugin install docs-workflow@claude-skills` |
| `/docs-init` | `docs-workflow` | `/plugin install docs-workflow@claude-skills` |
| `/docs-update` | `docs-workflow` | `/plugin install docs-workflow@claude-skills` |
| `/docs-claude` | `docs-workflow` | `/plugin install docs-workflow@claude-skills` |

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

Install skills via marketplace:

```bash
/plugin marketplace add https://github.com/jezweb/claude-skills
/plugin install project-workflow@claude-skills
/plugin install docs-workflow@claude-skills
/plugin install cloudflare-worker-base@claude-skills
```

---

**Version**: 6.0.0
**Last Updated**: 2026-01-11
**Author**: Jeremy Dawes | Jezweb
