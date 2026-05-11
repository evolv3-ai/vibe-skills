# Driving Flywheel from a Hermes Agent

This skill is portable to [Hermes Agent](https://github.com/NousResearch/hermes-agent) because the agentskills.io standard Hermes implements is identical to Claude Code's `SKILL.md` format. Most of the body applies as-is. The differences are environmental.

## Where the skill lives

| Operator | Skill path |
|----------|-----------|
| Claude Code on Windows host | `D:\flywheel\.claude\skills\flywheel-admin\` |
| Hermes Agent on wsl-hermes | `~/.hermes/skills/flywheel-admin/` |

To install on wsl-hermes from the Windows-side canonical copy:

```bash
# Run from wsl-hermes, with the Windows D: drive mounted at /mnt/d
mkdir -p ~/.hermes/skills
cp -r /mnt/d/flywheel/.claude/skills/flywheel-admin ~/.hermes/skills/
```

Keep wsl-hermes' copy in sync after edits. Either re-run that cp, or set up an `rsync` cron / `direnv`-triggered sync depending on how often the skill changes.

## SSH key + config

wsl-hermes already has the original OCI key at `~/.ssh/id_rsa` and the flywheel aliases in `~/.ssh/config`. The Windows host has a copy of the key at `C:\Users\Owner\.ssh\id_rsa_flywheel` plus its own `config`. Both work; they're independent.

## Path differences

The skill body uses `D:/flywheel/.claude/skills/...` in the **Skill Mirror** section because that's the canonical source on the Windows host. From wsl-hermes, the equivalent is:

```bash
scp -r "/mnt/d/flywheel/.claude/skills/." flywheel-N-oci:~/skills-staging/
# or, if the source has been copied into wsl-hermes:
scp -r "$HOME/.hermes/skills/." flywheel-N-oci:~/skills-staging/
```

Pick one canonical source and stick to it. Don't let the Windows and WSL copies diverge.

## Shell differences

Everywhere this skill says "PowerShell" — translate to bash. The SSH and `ntm` commands themselves are identical because they all run on the remote flywheel, not the operator. The only operator-side commands that differ are:

| Windows (PowerShell) | wsl-hermes (bash) |
|----------------------|-------------------|
| `$env:NTM_PROJECTS_BASE` | `$NTM_PROJECTS_BASE` |
| `C:\Users\Owner\.ssh\config` | `~/.ssh/config` |
| `scp "D:/flywheel/PRD.md" flywheel-1-oci:/...` | `scp /mnt/d/flywheel/PRD.md flywheel-1-oci:/...` (or `~/path/PRD.md`) |

## Agent harness differences

Hermes' skills loader, `/skills` palette, and autonomous skill-creation behavior differ from Claude Code's. This skill doesn't depend on any of that — it's pure procedural knowledge plus shell commands. If Hermes activates the skill and follows the SKILL.md body, it gets the same outcome Claude Code does.

The one runtime difference worth noting: **Hermes has procedural memory ("Skills Hub")**. After driving the fleet a few times, Hermes may auto-generate refinements to this skill. Treat those as suggestions; review and merge upstream into the canonical Windows-side copy rather than letting the wsl-hermes copy fork.

## What this skill does NOT cover

- Hermes installation/setup (use `~/.hermes` docs upstream).
- ACIP integration for prompt-injection defense on the Hermes side (relevant if Hermes is exposed via Tailscale funnel or messaging integrations — see https://github.com/Dicklesworthstone/acip).
- Cross-agent handoff between Claude Code and Hermes for the same task. If you need this, use ntm `checkpoint export` on one operator and `import` on the other; both produce the same archive format.
