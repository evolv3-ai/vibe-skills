---
description: Generate plugin manifests when creating or moving skills
alwaysApply: false
globs: ["**/SKILL.md", "**/skills/**"]
---

# Skill Manifest Reminder

When creating or moving skills in the claude-skills repo, **always generate plugin manifests**.

## Trigger

After any of these actions in `/home/jez/Documents/claude-skills/`:
- Creating a new skill directory
- Moving commands into a skill
- Renaming a skill
- Modifying skill YAML frontmatter

## Action

```bash
./scripts/generate-plugin-manifests.sh [skill-name]
```

Or for all skills:
```bash
./scripts/generate-plugin-manifests.sh
```

## Why

Plugin manifests (`skills/*/.claude-plugin/plugin.json`) are required for:
- Marketplace discovery
- `/plugin install` to work
- Agents bundled with skills to be found

Without the manifest, the skill exists but can't be installed via the plugin system.

## Checklist

Before committing skill changes:
- [ ] SKILL.md has valid YAML frontmatter
- [ ] README.md has keywords
- [ ] **Plugin manifest generated** ← Easy to forget!
- [ ] Committed and pushed

**Last Updated**: 2026-02-02
