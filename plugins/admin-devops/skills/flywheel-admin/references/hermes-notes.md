# Driving Flywheel from a Hermes Agent

This skill is portable to [Hermes Agent](https://github.com/NousResearch/hermes-agent) because the agentskills.io standard Hermes implements is identical to Claude Code's `SKILL.md` format. Most of the body applies as-is. The differences are environmental.

## Where the skill lives

| Operator | Skill path |
|----------|-----------|
| Claude Code on the Windows host | `<skills-bundle>\flywheel-admin\` — your canonical local bundle (the `SKILLS_SRC` of the Skill Mirror section) |
| Hermes Agent on the WSL operator | `~/.hermes/skills/flywheel-admin/` |

To install on the WSL operator from the Windows-side canonical copy:

```bash
# Run from WSL, with the Windows drive mounted (e.g. /mnt/c or /mnt/d)
mkdir -p ~/.hermes/skills
cp -r "$SKILLS_SRC/flywheel-admin" ~/.hermes/skills/   # SKILLS_SRC = WSL view of your bundle
```

Keep the WSL copy in sync after edits. Either re-run that cp, or set up an `rsync` cron / `direnv`-triggered sync depending on how often the skill changes.

## SSH key + config

Each operator surface keeps its own key and ssh config with the fleet aliases from `profile.servers[]` — `~/.ssh/config` on WSL, `%USERPROFILE%\.ssh\config` on the Windows host (see [connect.md](connect.md)). Both work; they're independent.

## Path differences

The skill body's **Skill Mirror** section pushes from `$SKILLS_SRC` — the canonical source on the Windows host. From the WSL operator, the equivalent is the mounted-drive view of the same directory, or the local copy:

```bash
scp -r "$SKILLS_SRC/." flywheel-N:~/skills-staging/
# or, if the source has been copied into the WSL operator:
scp -r "$HOME/.hermes/skills/." flywheel-N:~/skills-staging/
```

Pick one canonical source and stick to it. Don't let the Windows and WSL copies diverge.

## Shell differences

Everywhere this skill says "PowerShell" — translate to bash. The SSH and `ntm` commands themselves are identical because they all run on the remote flywheel, not the operator. The only operator-side commands that differ are:

| Windows (PowerShell) | WSL operator (bash) |
|----------------------|---------------------|
| `$env:NTM_PROJECTS_BASE` | `$NTM_PROJECTS_BASE` |
| `%USERPROFILE%\.ssh\config` | `~/.ssh/config` |
| `scp "C:\path\to\PRD.md" flywheel-1:/...` | `scp /mnt/c/path/to/PRD.md flywheel-1:/...` (or `~/path/PRD.md`) |

## Agent harness differences

Hermes' skills loader, `/skills` palette, and autonomous skill-creation behavior differ from Claude Code's. This skill doesn't depend on any of that — it's pure procedural knowledge plus shell commands. If Hermes activates the skill and follows the SKILL.md body, it gets the same outcome Claude Code does.

The one runtime difference worth noting: **Hermes has procedural memory ("Skills Hub")**. After driving the fleet a few times, Hermes may auto-generate refinements to this skill. Treat those as suggestions; review and merge upstream into the canonical Windows-side copy rather than letting the WSL copy fork.

## What this skill does NOT cover

- Hermes installation/setup (use `~/.hermes` docs upstream).
- ACIP integration for prompt-injection defense on the Hermes side (relevant if Hermes is exposed via Tailscale funnel or messaging integrations — see https://github.com/Dicklesworthstone/acip).
- Cross-agent handoff between Claude Code and Hermes for the same task. If you need this, use ntm `checkpoint export` on one operator and `import` on the other; both produce the same archive format.
