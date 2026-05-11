# Operator Loop — Tending a Swarm

> The SKILL.md gives the 6-phase outline. This file is the depth on phase 5: how to drive a swarm without burning the operator's time or wedging an agent.

## Cadence

A healthy swarm needs an operator about every 5–15 minutes. Less than that and you miss `action_required` events; more than that and you're poll-wasting context. Use the attention feed, not a timer.

```bash
# Bootstrap once
ssh flywheel-N-oci 'ntm --robot-snapshot --robot-format=toon --robot-verbosity=terse'

# Then block until something happens
ssh flywheel-N-oci 'ntm --robot-wait=<name> --wait-until=attention,mail_ack_required,action_required --timeout=10m'
```

If `--robot-wait` returns events, act on each. If it returns "timeout, no events", probe with `ntm --robot-diagnose=<name>` — silence usually means stuck, not done.

## Probe before you interrupt

Never `ntm send` blind to a pane that may be mid-thought. The polite probe ladder:

1. `ntm --robot-is-working=<name> --panes=N` — instant working/idle check.
2. `ntm --robot-context=<name>` — context-window usage per agent. >90 % means imminent /clear.
3. `ntm --robot-tail=<name> --panes=N --lines=50` — read what it's doing.
4. `ntm --robot-probe=<name> --panes=N` — responsiveness probe (sends a no-op, times out).

Then act:

- Working but on wrong path → `ntm send <name> --pane=N "Pause. Step back: <correction>."`
- Idle, waiting on you → `ntm send <name> --pane=N "<next directive>"`
- Unresponsive → unstick ladder below.

## Unstick ladder

Apply in order; stop as soon as the agent responds.

1. **Soft nudge** — `ntm send <name> --pane=N "Status?"`. Many "stuck" agents just need a prompt.
2. **Smart restart** — `ntm --robot-smart-restart=<name> --panes=N`. Refuses if actively working; safe to try.
3. **Interrupt** — `ntm --robot-interrupt=<name> --panes=N`. Sends Ctrl-C equivalent.
4. **Hard respawn** — `ntm respawn <name>`. Recovers dead agents in place; preserves session.
5. **Checkpoint + tear down** — `ntm checkpoint save <name> -m "stuck"; ntm swarm stop <name>; ntm spawn <name> ...`.

Never start at step 4. The probe data from steps 1–3 informs the marching orders you give after restart.

## When to checkpoint

Checkpoint before:
- Any migration, schema change, or destructive bulk operation
- Letting agents run unsupervised for >30 min
- Cross-machine handoff (`ntm checkpoint export` → `import`)
- A swarm-stop you might want to roll back

```bash
ssh flywheel-N-oci 'ntm checkpoint save <name> -m "before <thing>"'
ssh flywheel-N-oci 'ntm checkpoint list <name>'
ssh flywheel-N-oci 'ntm checkpoint restore <name>'   # latest
```

## When to checkpoint vs respawn vs swarm-stop

| Symptom | Action |
|---------|--------|
| One pane wedged, others healthy | `ntm respawn` |
| Multiple panes flailing on the same wrong path | `swarm stop` + new `spawn` with corrected `AGENTS.md` |
| Right path, but context exhausted | tell agents to `/clear` and re-read `AGENTS.md` + their assigned bead |
| Major direction change needed mid-flight | `checkpoint save` → re-spawn with new prompt |
| Done, want to preserve state | `checkpoint export` + `scp` to operator |

## File reservations

When agents are about to touch overlapping files, push them to use `agent-mail` file reservations explicitly. Check who's holding what:

```bash
ssh flywheel-N-oci 'ntm locks list <name> --all-agents'
ssh flywheel-N-oci 'ntm locks force-release <name> 42 --note "agent inactive"'
```

A pane stuck waiting on a lock is a common failure mode for swarms larger than 2–3 agents.

## Coordinator pattern

For long-running or large swarms (≥4 agents), spawn a dedicated coordinator pane:

```bash
ssh flywheel-N-oci 'ntm controller <name>'
```

The coordinator polls the attention feed, assigns work, resolves conflicts, and surfaces only the things the human operator must decide. Frees you to work elsewhere; come back for `action_required` only.

## Anti-patterns

- **`ntm view` in automation** — it retiles the human operator's tmux layout and returns nothing useful. Operator-only.
- **`--all` blasts** — `ntm send <name> --all "X"` hits the user pane too. Use `-s/--skip-first` or just target panes explicitly.
- **Polling instead of waiting** — burns context. Use `--robot-wait` or the coordinator.
- **Killing a working pane** — always probe first. A pane mid-edit-conflict resolution looks stuck but isn't.
- **Skipping checkpoints before migrations** — the only thing more painful than a failed migration is a failed migration without rollback state.
