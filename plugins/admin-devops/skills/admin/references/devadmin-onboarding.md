# devadmin onboarding & migration

Reference for `/admin-devops:adopt-devadmin` — how a host is brought onto (or migrated
to) the shared Open Engine `devadmin` host-ops backlog. The command is the executable
form of this document; this is the why and the decision tree.

## What "adopted" means

A host is **adopted** when all of the following are true:

| Surface | In place when… |
| -- | -- |
| Linear project | `devadmin` project exists (`https://linear.app/evolv3ai/project/devadmin-28dcbcd13f7b`) |
| Host label | `host:<slug>` label exists in the EVO team |
| Seat | this runtime's agent code is on the EVO-54 routing map and its EVO-53 ledger entry says `installed` (`online`) |
| Workspace | canonical workspace exists (`D:\devadmin` native · `~/dev/devadmin` WSL/Linux) with a current-shape `CLAUDE.md` |
| Routing map | the host has a row under EVO-54 → *Shared cross-host backlog: `devadmin`* and the seat status is `online` |

Idempotency target: on an already-adopted host the command finds all five in place
and reports **nothing to do**.

## The two migration sources

The command covers drift from two directions:

**(a) Other ticket systems → devadmin local tracker.** v1 understands the local
`~/.admin/issues/*.md` files (the `/troubleshoot` format) and GitHub Issues (admin-devops
already integrates `gh` per `/wrap-up`). Routable, still-open items can be *mirrored up*
to the `devadmin` Linear project; the local file stays authoritative. v2 can plug in
others (Jira, a Linear team, plain markdown).

**(b) Older admin-devops skill shapes → current shape.** Driven entirely by
**retired-path detection** plus **CLAUDE.md shape diff**. The retired-path table in the
CLAUDE.md template (`assets/devadmin/CLAUDE.md.*.template`) *is* the migration spec:
keeping that table current keeps this command current. No per-shape migration code —
add a row, the detector picks it up.

## Flow

```
            ┌─────────────────────────────────────────────────────────┐
            │ 0. Profile gate (mandatory) — no profile → /setup-profile│
            └───────────────────────────┬─────────────────────────────┘
                                        │
            ┌───────────────────────────▼─────────────────────────────┐
            │ 1. Detect current shape (READ-ONLY)                      │
            │    • local: devadmin-adopt.sh / .ps1                     │
            │        - workspace + CLAUDE.md shape version             │
            │        - retired paths on disk                           │
            │        - local issue census (open/resolved)             │
            │        - profile → placeholders                          │
            │    • Linear (MCP): project? host:<slug> label?           │
            │        seat on EVO-54? EVO-53 status == installed?       │
            └───────────────────────────┬─────────────────────────────┘
                                        │
            ┌───────────────────────────▼─────────────────────────────┐
            │ 2. Diff report — in place ✓ vs missing ✗                 │
            └───────────────────────────┬─────────────────────────────┘
                                        │
        ┌───────────────────────────────▼───────────────────────────────┐
        │ 3. Walk MISSING steps, AskUserQuestion checkpoint at each branch│
        │    a. Linear surface  — create project? create host label?     │
        │    b. Seat            — not online → run smoke test (in-seat)   │
        │    c. Workspace       — scaffold from template; offer to move   │
        │                         host-grown content from old folder      │
        │    d. Issue migration — mirror routable+open local issues up    │
        │                         (scrub secrets; local stays source)     │
        │    e. Old folders     — enumerate; STAGE for manual rm -rf only │
        └───────────────────────────────┬───────────────────────────────┘
                                        │
            ┌───────────────────────────▼─────────────────────────────┐
            │ 4. Update routing map (EVO-54) — add host row; → online   │
            │ 5. Log OK event (log-admin-event.sh / Log-AdminEvent.ps1) │
            │ 6. Report — URLs/paths + manual TODO checklist            │
            └─────────────────────────────────────────────────────────┘
```

## Decision tree

```
Is the devadmin project reachable via Linear MCP?
├─ no  → STOP. Wire Linear MCP for THIS seat first (see EVO-58 / open-engine-admin).
└─ yes →
   Does host:<slug> label exist?
   ├─ no  → [checkpoint] create it (EVO team).
   └─ yes →
      Does the canonical workspace exist with current CLAUDE.md shape?
      ├─ no workspace            → [checkpoint] scaffold from template.
      ├─ workspace, stale shape  → [checkpoint] re-instantiate CLAUDE.md (back up old).
      └─ workspace, current      → ok.
      Any retired-path folders on disk?
      ├─ yes → [checkpoint] offer to MOVE host-grown content into workspace,
      │         then STAGE old folder for manual deletion (never auto rm).
      └─ no  → ok.
      Local issues present and untracked in Linear?
      ├─ yes → [checkpoint] offer to mirror routable+open ones up (scrub secrets).
      └─ no  → ok.
      Is this seat's EVO-53 status `installed`?
      ├─ no  → run the in-seat smoke test end-to-end (cannot be proxied).
      └─ yes → ok.
      → Update EVO-54 row to `online`, log OK, report.
```

## Runtime → template → workspace

| Profile `ADMIN_PLATFORM` | Template | Workspace | Suggested agent code |
| -- | -- | -- | -- |
| `windows` | `CLAUDE.md.native.template` | `D:\devadmin` | `<slug>-claude-cli` |
| `macos` / `linux` (native) | `CLAUDE.md.native.template` | `~/dev/devadmin` | `<slug>-claude-cli` |
| `wsl` | `CLAUDE.md.wsl.template` | `~/dev/devadmin` | `<slug>-claude-cli-wsl` |

The suggested agent code is a *starting point*. Always confirm it against the EVO-54
roster — an existing ledger code wins (per the agent-code convention in EVO-58). WSL is
a **distinct seat** from the host's native seat: separate MCP/OAuth, separate smoke
test, separate code.

Host slug map: `WOPR3`→`wopr3`, `DELTABOT`→`delta`, `CASATEN`/`CASA`→`casa`; otherwise
the lowercased alphanumeric device name.

## Guardrails (enforced by the command)

- **Never auto-delete a retired folder.** Move content, then output a `rm -rf` /
  `Remove-Item` checklist for the user to run after they confirm.
- **Never paste secrets into Linear.** Scrub `.env`-style content from any local issue
  body before mirroring it up.
- **Profile changes require confirmation.** Never silently rewrite preferences from
  detected state.
- **The smoke test runs in the target seat.** MCP/OAuth must be exercised on the right
  host/profile/WSL home; the command cannot proxy a smoke test from another seat. When
  the command *is* running in the target seat, running the claim→hello→done loop inline
  is correct (the "admin-is-seat" case from `open-engine-admin`).

## Related

- Routing map: EVO-54 → *Shared cross-host backlog: `devadmin`* (the section is the spec).
- Status ledger format: EVO-53.
- Access / contract: EVO-58.
- Open Engine control-plane patterns: `open-engine-skills` → `open-engine-admin` skill.
- Templates + placeholders: `assets/devadmin/README.md`.
- Local issue tracking: `/admin-devops:troubleshoot`.
