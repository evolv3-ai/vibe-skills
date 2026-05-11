---
name: flywheel-admin
description: >-
  Operator skill for driving the Agentic Coding Flywheel (ACFS) fleet from outside.
  Use when the user wants to provision, connect to, inspect, deploy PRDs to, or
  recover Flywheel VPS instances; spawn or tend multi-agent swarms on a flywheel;
  mirror the local skills bundle to flywheels; or troubleshoot fleet-wide issues.
  Works for both Claude Code (Windows host) and Hermes agents (WSL/Linux). Triggers:
  "deploy to flywheel", "spawn a swarm on flywheel-N", "check flywheel health",
  "provision a new flywheel", "send PRD to flywheel", "what's running on the fleet",
  "sync skills to flywheels", "flywheel doctor".
---

<!-- TOC: Mental Model | Fleet | Operator Loop | Skill Mirror | Provisioning | Quirks | References | Companions -->

# Flywheel Admin — Drive the ACFS Fleet

> **Scope:** orchestration of remote Flywheel VPSs running ACFS. NOT per-tool reference
> for ntm/agent-mail/cass/etc. — those have their own skills; this one tells you which to
> reach for and in what order.

> **Read first.** Always read the project's `CLAUDE.md` before acting — it is the source
> of truth for the current fleet inventory, Tailscale hostnames, SSH config, and any
> recent operational notes. This skill captures the *patterns*; CLAUDE.md captures
> *today's state*.

> **Found a bug or missing pattern in this skill? Do NOT try to fix it inline.**
> File an issue at **https://github.com/evolv3-ai/vibe-skills/issues** with a clear title
> (e.g. `flywheel-admin: <symptom>`), what you were trying to do, the exact command(s)
> that misbehaved, and the actual vs expected outcome. A repo-side dev workflow watches
> this tracker and will generate a fix + push a commit. The reason: external agents
> driving this skill rarely have the full operator context (current fleet inventory,
> Tailscale state, in-flight session notes) and inline fixes tend to drift from the
> canonical source. Report → don't patch.

## Mental Model

A **flywheel** is a remote VPS running [ACFS](https://github.com/Dicklesworthstone/agentic_coding_flywheel_setup): Ubuntu + the Dicklesworthstone agent stack (ntm, agent-mail, beads, cass, dcg, slb, …) + Claude Code / Codex CLI / Gemini CLI. The local machine (Windows host or wsl-hermes) is the **operator** — it never runs agents itself, it drives swarms on flywheels via SSH (preferred over Tailscale MagicDNS).

Three layers, in dependency order:

1. **Transport** — SSH over Tailscale. If Tailscale is down, fall back to public IP.
2. **Project** — a directory under `/data/projects/<name>` on the flywheel with a `PRD.md`, `AGENTS.md`, and (usually) a beads database.
3. **Swarm** — an `ntm` session of tmux panes, one per agent (Claude/Codex/Gemini), coordinated via Agent Mail + Beads.

You operate at layer 3 most of the time. When something breaks, work down: probe transport, then check project state, then inspect panes.

## Fleet

Read `CLAUDE.md` in this repo for the live inventory. The current fleet is small (2 hosts) and Tailscale-joined under the `dwelf-stork.ts.net` tailnet. SSH aliases on the Windows host (`C:\Users\Owner\.ssh\config`) and on wsl-hermes resolve `flywheel-1-oci` and `flywheel-2-oci` directly. Always prefer the alias over raw IPs — if Tailscale is up, MagicDNS Just Works.

```bash
# From any operator (Windows PowerShell, WSL, or any tailnet-joined client)
ssh flywheel-1-oci 'acfs doctor'
ssh flywheel-2-oci 'ntm list'
```

For all connection paths (Windows / WSL / public-IP fallback) and SSH keys, see
[references/connect.md](references/connect.md).

## The Operator Loop

Every Flywheel session follows this loop. Skip phases you've already done.

### 1. Discover — what's the fleet doing right now?

```bash
# Health snapshot per host (run in parallel if you can)
ssh flywheel-1-oci 'uptime; free -h | head -2; df -h / | tail -1; acfs doctor 2>&1 | tail -5; ntm list'
ssh flywheel-2-oci 'uptime; free -h | head -2; df -h / | tail -1; acfs doctor 2>&1 | tail -5; ntm list'
```

Red flags: load > #CPUs, memory >85 %, disk >75 %, `acfs doctor` red lines, dead `ntm list`.

### 2. Pick a target — which flywheel for this work?

| Need | Pick |
|------|------|
| Stable, mature Ubuntu 24.04 | flywheel-1 (lower disk headroom — watch it) |
| Newest stack, PostgreSQL, beads_rust, meta_skill | flywheel-2 |
| Two independent swarms in parallel | one each |

If both are loaded, prefer scaling on the host with the most free RAM rather than spinning a third VPS.

### 3. Prepare the project

```bash
# Create the project dir if new
ssh flywheel-N-oci 'mkdir -p /data/projects/<name>'

# Copy in PRD + AGENTS.md
scp PRD.md AGENTS.md flywheel-N-oci:/data/projects/<name>/

# Optional: clone an existing repo to seed
ssh flywheel-N-oci 'cd /data/projects/<name> && git clone <url> .'
```

Confirm `NTM_PROJECTS_BASE` resolves to `/data/projects`:

```bash
ssh flywheel-N-oci 'ntm config get projects_base'
```

The session name MUST equal the directory basename. Cross-tool breakage between ntm,
agent-mail, and beads almost always traces to a mismatch here.

### 4. Spawn the swarm

```bash
# 2 Claude + 1 Codex, classic starter swarm
ssh flywheel-N-oci 'cd /data/projects/<name> && ntm spawn <name> --cc=2 --cod=1'

# Add a Gemini for review-only work
ssh flywheel-N-oci 'cd /data/projects/<name> && ntm spawn <name> --cc=2 --cod=1 --gmi=1'

# Worktree isolation when agents will touch the same files
ssh flywheel-N-oci 'cd /data/projects/<name> && ntm spawn <name> --cc=3 --worktrees'

# Kick the swarm
ssh flywheel-N-oci 'ntm send <name> --all "Read PRD.md and AGENTS.md, then begin."'
```

For all spawn knobs (recipes, workflows, personas, stagger modes), use the `ntm`
companion skill, not this one.

### 5. Drive / monitor

Prefer **event-driven tending** over polling. Bootstrap once with a snapshot, then block on the attention feed until something happens.

```bash
ssh flywheel-N-oci 'ntm --robot-snapshot --robot-format=toon'
ssh flywheel-N-oci 'ntm --robot-wait=<name> --wait-until=attention --timeout=5m'

# Tail a specific pane
ssh flywheel-N-oci 'ntm --robot-tail=<name> --panes=2 --lines=50'

# Inbox / coordination
ssh flywheel-N-oci 'ntm mail inbox <name> --json'
ssh flywheel-N-oci 'ntm locks list <name> --all-agents'

# Send corrective input
ssh flywheel-N-oci 'ntm send <name> --pane=2 "Refactor: extract validateInput into auth/validate.go"'
```

The fully-developed operator loop (probe-before-interrupt, stuck-pane unstick ladder,
when to checkpoint vs respawn) is in [references/operator-loop.md](references/operator-loop.md).

### 6. Wrap / recover

```bash
# Checkpoint before anything risky (migrations, force-pushes, schema changes)
ssh flywheel-N-oci 'ntm checkpoint save <name> -m "before <thing>"'

# Pull artifacts back to the operator
scp -r flywheel-N-oci:/data/projects/<name>/dist ./

# Tear down a finished swarm
ssh flywheel-N-oci 'ntm swarm stop <name>'
```

If a swarm is stuck and the panes won't respond, use the unstick ladder in
[references/operator-loop.md](references/operator-loop.md) before killing anything.

## Skill Mirror

The local `.claude/skills/` bundle is the canonical source. After non-trivial changes here, push to both flywheels so all three remote agent families (Claude / Codex / Gemini) see the same set:

```bash
# Repeat per flywheel
ssh flywheel-N-oci 'mkdir -p ~/skills-staging ~/.claude/skills ~/.codex/skills ~/.gemini/skills'
scp -r "D:/flywheel/.claude/skills/." flywheel-N-oci:~/skills-staging/
ssh flywheel-N-oci 'cp -r ~/skills-staging/. ~/.claude/skills/ \
  && cp -r ~/skills-staging/. ~/.codex/skills/ \
  && cp -r ~/skills-staging/. ~/.gemini/skills/ \
  && rm -rf ~/skills-staging'
```

For Hermes operators, also mirror to `~/.hermes/skills/` on wsl-hermes (the format is
the agentskills.io open standard — identical to Claude Code). See
[references/hermes-notes.md](references/hermes-notes.md).

## Provisioning a New Flywheel

This is the rare path. Don't reach for it unless the existing fleet can't absorb the work.

1. Pick a provider — `admin-devops:oci`, `admin-devops:hetzner`, `admin-devops:digital-ocean`, etc. (each has a dedicated skill). OCI ARM64 Always-Free is the current default.
2. Bring the VM up via the provider's skill; install Ubuntu 24.04 LTS (LTS, not interim).
3. Join the tailnet `dwelf-stork.ts.net` (`sudo tailscale up --authkey=...`).
4. Bootstrap ACFS: `curl -fsSL https://raw.githubusercontent.com/Dicklesworthstone/agentic_coding_flywheel_setup/main/install.sh | bash -s -- --easy-mode --skip-ubuntu-upgrade`.
5. Verify with `acfs doctor`; expect ≥ 40/45 green.
6. Patch known ACFS-v0.5.0/v0.6.0 quirks — see [references/known-quirks.md](references/known-quirks.md) (ARM64 DCG binary, agent-mail Rust vs Python, bubblewrap, SSH keepalive).
7. Mirror the skills bundle (see above).
8. Add the new host to `CLAUDE.md` and to `~/.ssh/config` on Windows and wsl-hermes.

## Quirks (must-know)

- ACFS v0.5.0 is the current pinned version on both hosts; v0.6.0 is upstream. Refresh `~/.acfs/checksums.yaml` before `acfs-update --stack` or it bails.
- DCG aarch64 release tarball ships the wrong-arch binary. Build from source.
- Agent Mail comes in Python and Rust flavors; the Rust one is what ACFS actually wants. Don't trust `acfs doctor` recommending the Python repo.
- `ntm send` excludes the operator pane by default. `--all` includes it. Don't blast a `--all` to a session you haven't checked.
- Session name MUST equal `<projects_base>/<name>` basename, or agent-mail registers under a different key than ntm. Most common breakage.

Full list with fixes in [references/known-quirks.md](references/known-quirks.md).

## References

- [connect.md](references/connect.md) — every SSH path from every operator surface (Windows / WSL / tailnet / public-IP fallback) with keys.
- [operator-loop.md](references/operator-loop.md) — phase 5 in depth: tending cadence, unstick ladder, when to checkpoint vs respawn vs swarm-stop.
- [known-quirks.md](references/known-quirks.md) — every ACFS / flywheel-specific gotcha with the exact fix.
- [hermes-notes.md](references/hermes-notes.md) — adjustments when this skill is driven by a Hermes agent on wsl-hermes instead of Claude Code on the Windows host.

## Companion Skills

This skill orchestrates; the per-tool skills do the actual work. Reach for them when:

| Tool | Skill | When |
|------|-------|------|
| ntm | `ntm` | Anything pane- or session-level on a flywheel |
| agent-mail | `agent-mail` | Reservations, inboxes, contact handshakes |
| beads_rust | `beads-br` | Task graph on the flywheel |
| bv | `beads-bv` | Graph-aware triage / "what's next" |
| cass / cm | `cass`, `cass-memory` | Cross-session retrieval, procedural memory |
| dcg | `dcg` | Destructive-command guard rails |
| slb | `slb` | Two-person rule for dangerous commands |
| caam | `caam` | Swap AI-provider accounts when rate-limited |
| OCI provisioning | `admin-devops:oci` | New flywheels on Oracle Cloud |
| Hetzner / DO / Linode / Vultr | `admin-devops:<provider>` | Alternate providers |
| Coolify / KASM | `admin-devops:coolify`, `admin-devops:kasm` | App-hosting layer on top of a flywheel |
