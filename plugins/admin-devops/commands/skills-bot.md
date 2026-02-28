---
name: skills-bot
description: Manage Claude Code skills - install, update, list, and configure via registry
allowed-tools:
  - Read
  - Write
  - Bash
  - AskUserQuestion
argument-hint: "[install | list | update | sync | info <name>]"
---

# /skills-bot Command

Manage Claude Code skills using a local registry stored in `~/.admin/skills-registry.json`.

## Registry Location

Skills are tracked in:
```
~/.admin/skills-registry.json
```

Skills are installed to:
```
~/.claude/skills/
```

## Workflow by Subcommand

### `/skills-bot list` - List Installed Skills

Read the skills registry and display:

```
Name                    | Version | Source      | Status   | Last Updated
------------------------|---------|-------------|----------|-------------
admin                   | 0.1.0   | local       | active   | 2026-02-04
devops                  | 0.1.0   | local       | active   | 2026-02-04
tailwind-v4-shadcn      | 1.2.0   | marketplace | active   | 2026-02-01
cloudflare-worker-base  | 1.0.0   | marketplace | disabled | 2026-01-15
```

Status values:
- `active` - Skill is enabled and working
- `disabled` - Skill exists but manually disabled
- `outdated` - Newer version available
- `missing` - In registry but skill files missing

### `/skills-bot install` - Install New Skill

Use TUI to guide installation:

#### Q1: Installation Source
Ask: "Where would you like to install the skill from?"

| Option | Description |
|--------|-------------|
| Marketplace | Official jezweb/claude-skills marketplace |
| Git Repository | Clone from any Git URL |
| Local Path | Copy from local directory |
| Browse Available | See list of available skills |

#### Q2: Skill Selection (if "Browse Available")
Ask: "Which skill would you like to install?"

Display available skills from marketplace manifest or local catalog.

#### Q3: Installation Options
Ask: "Any additional options?"

| Option | Description |
|--------|-------------|
| Install dependencies | Run post-install scripts |
| Create symlink | Symlink instead of copy (dev mode) |
| Add to profile | Track in device profile |

Then perform installation:

1. Download/copy skill files to `~/.claude/skills/<name>/`
2. Verify `SKILL.md` exists
3. Update skills registry
4. Log the operation

### `/skills-bot update` - Update Skills

Check for updates and apply:

#### Q1: Update Scope
Ask: "What would you like to update?"

| Option | Description |
|--------|-------------|
| All skills | Update all installed skills |
| Specific skill | Select one skill to update |
| Check only | Just check for updates, don't apply |

Then:
1. Compare local version with source version
2. Show diff of changes (optional)
3. Backup current version
4. Apply update
5. Update registry

### `/skills-bot sync` - Sync Registry

Scan `~/.claude/skills/` and update registry to match:

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/skills-sync.sh"
sync_skills_registry
```

This:
1. Finds all skill directories with `SKILL.md`
2. Extracts metadata from each skill
3. Updates registry with current state
4. Reports discrepancies

### `/skills-bot info <name>` - Show Skill Details

Display detailed information about a skill:

```
Skill: tailwind-v4-shadcn
Version: 1.2.0
Source: marketplace (jezweb/claude-skills)
Status: active
Path: ~/.claude/skills/tailwind-v4-shadcn/

Description:
  Build modern UIs with Tailwind CSS v4 and shadcn/ui components.
  Use when: creating React apps with Tailwind, adding shadcn components.

Keywords: tailwind, shadcn, react, ui, components

Files:
  - SKILL.md (main skill)
  - scripts/install-tailwind.sh
  - templates/tailwind.config.ts
  - references/components.md

Last Updated: 2026-02-01
Install Date: 2026-01-15
Usage Count: 47 (this month)
```

## Skills Registry Format

```json
{
  "version": "1.0.0",
  "lastSync": "2026-02-04T12:00:00Z",
  "skills": {
    "admin": {
      "name": "admin",
      "version": "0.1.0",
      "description": "Local machine administration...",
      "source": {
        "type": "local",
        "path": "~/dev/evolv3ai-skills/skills/admin"
      },
      "status": "active",
      "path": "~/.claude/skills/admin",
      "installedAt": "2026-02-04T12:00:00Z",
      "updatedAt": "2026-02-04T12:00:00Z",
      "usageCount": 0,
      "keywords": ["install", "windows", "wsl", "mcp"]
    },
    "tailwind-v4-shadcn": {
      "name": "tailwind-v4-shadcn",
      "version": "1.2.0",
      "description": "Build modern UIs with Tailwind CSS v4...",
      "source": {
        "type": "marketplace",
        "repo": "jezweb/claude-skills",
        "ref": "main"
      },
      "status": "active",
      "path": "~/.claude/skills/tailwind-v4-shadcn",
      "installedAt": "2026-01-15T12:00:00Z",
      "updatedAt": "2026-02-01T12:00:00Z",
      "usageCount": 47,
      "keywords": ["tailwind", "shadcn", "react"]
    }
  },
  "sources": {
    "marketplace": {
      "url": "https://github.com/jezweb/claude-skills",
      "lastFetch": "2026-02-04T12:00:00Z"
    }
  }
}
```

## Helper Scripts

Sync registry:
```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/skills-sync.sh"
sync_skills_registry
```

Update registry entry:
```powershell
& "${CLAUDE_PLUGIN_ROOT}/scripts/skills-update-registry.ps1" `
  -SkillName "admin" `
  -Field "status" `
  -Value "disabled"
```

## Tips

- Run `/skills-bot sync` after manually adding skills
- Use symlinks for skills in active development
- Check `/skills-bot info` to understand skill capabilities
- Registry tracks usage for analytics (local only)
- Backup registry before major updates: `cp ~/.admin/skills-registry.json ~/.admin/skills-registry.backup.json`
