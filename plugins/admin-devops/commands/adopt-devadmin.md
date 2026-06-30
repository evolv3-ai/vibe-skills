---
name: adopt-devadmin
description: Onboard or migrate this host onto the shared Open Engine devadmin host-ops backlog (Linear surface, seat, workspace, routing map) — idempotent
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
  - AskUserQuestion
argument-hint: "[--detect-only] [--platform native|wsl]"
---

# /adopt-devadmin Command

Bring **this host** onto the shared Open Engine `devadmin` host-ops backlog, or migrate
it from an older admin-devops shape to the current one. Idempotent: on a host that is
already adopted it reports *nothing to do*.

**Requires Linear MCP connected for this seat.** This whole flow reads and writes the
Linear surface via MCP. If Linear MCP tools do not respond in this session, stop and
wire it first (`claude mcp add --transport http linear-server https://mcp.linear.app/mcp`,
then `/mcp` to log in) — see `EVO-58` and the `open-engine-admin` skill. MCP wiring is
per host/profile/WSL home, so a different seat's wiring does not count.

Workflow background and the decision tree: `skills/admin/references/devadmin-onboarding.md`.
Templates and placeholders: `skills/admin/assets/devadmin/README.md`.

Canonical Linear surface:

| Surface | Value |
| -- | -- |
| Project | `devadmin` — https://linear.app/evolv3ai/project/devadmin-28dcbcd13f7b |
| Team | `EVO` / Evolv3ai · operator `Evolv3 AI` / `hello@evolv3.ai` |
| Queue label | `agent-instructions` (mandatory) · host filter `host:<slug>` |
| Routing map | `EVO-54` → section *Shared cross-host backlog: `devadmin`* |
| Status ledger | `EVO-53` |
| Access guide | `EVO-58` |

---

## Step 0 — Profile gate (mandatory first step)

No profile → no host identity, no logging path, no placeholders. Run:

```bash
"${CLAUDE_PLUGIN_ROOT}/skills/admin/scripts/test-admin-profile.sh"
```

(Windows: `pwsh -NoProfile -File "$env:CLAUDE_PLUGIN_ROOT\skills\admin\scripts\Test-AdminProfile.ps1"`)

If `exists:false`, stop and run `/admin-devops:setup-profile`, then re-run this command.
See `references/profile-gate.md` for the fallback when scripts are unavailable.

## Step 1 — Detect current shape (read-only)

Run the detector for this platform. It never writes and never touches the network:

```bash
"${CLAUDE_PLUGIN_ROOT}/skills/admin/scripts/devadmin-adopt.sh" --pretty
```

Windows-native seats:

```powershell
pwsh -NoProfile -File "$env:CLAUDE_PLUGIN_ROOT\skills\admin\scripts\devadmin-adopt.ps1"
```

Parse the JSON. It reports `host`, `hostSlug`, `hostLabel`, `platform`,
`suggestedAgentCode`, `workspace` (path/exists/CLAUDE.md shape + staleness),
`template` (kind/file/shapeVersion), `retiredPaths[]`, `localIssues`
(total/open/resolved), and a `placeholders` object for template instantiation.

Then check the **Linear half via MCP** (read-only):

1. `devadmin` project exists? (`list_projects` / `get_project devadmin`).
2. `host:<slug>` label exists? (`list_issue_labels` for team EVO).
3. This seat's agent code is on the `EVO-54` routing map devadmin section?
4. This seat's `EVO-53` `AGENT STATUS` comment says `Automation state: installed`
   (→ `online`)?

Confirm the **agent code**: prefer an existing EVO-54 / EVO-53 code for this runtime
over `suggestedAgentCode`. WSL is a distinct seat from the native seat — its code ends
`-wsl`. If no code exists for this runtime, propose one (`<slug>-<runtime>[-wsl]`) and
confirm with the user before using it.

## Step 2 — Diff report

Present a compact table: each surface (project, host label, seat/ledger, workspace +
shape, routing-map row, local-issue migration, retired folders) marked **✓ in place**
or **✗ missing / stale**. If everything is ✓, say **nothing to do** and stop after
optionally refreshing the EVO-53 heartbeat. Otherwise continue.

## Step 3 — Walk the missing steps (checkpoint each branch)

Use `AskUserQuestion` before each mutating branch. Do only what's missing.

### 3a. Linear surface
- **Project** absent (shouldn't normally happen): confirm, then create `devadmin` in
  team EVO (omit `icon` — the MCP `save_project` tool rejects it).
- **`host:<slug>` label** absent: confirm, then `create_issue_label` in team EVO.

### 3b. Seat / smoke test
If the seat is not `online`, run the smoke test **end-to-end from inside this seat** —
it cannot be proxied (MCP/OAuth must be exercised on this host/profile/WSL home):
1. Add/update this seat's `AGENT STATUS` comment on `EVO-53` (format per EVO-53;
   `Last queue result: checking`, current ISO8601 timestamp).
2. Find or create `[agent instructions][<agent-code>][task] Say hello from the queue`
   in the `devadmin` project, labels `agent-instructions` + `host:<slug>`, assigned to
   the operator, state `Agent Todo`.
3. Claim it (move to `Agent Working`, comment `AGENT CLAIMED`), re-read, comment a
   short hello, comment `AGENT DONE`, move to `Agent Done`.
4. Update the EVO-53 comment to `completed <ISSUE>` and `Automation state: installed`.

This is the "admin-is-seat" case: claiming the test as the seat you actually are is
correct, not a violation.

### 3c. Workspace folder
- **No workspace**: scaffold the canonical path (`workspace.path` from the detector)
  and write `CLAUDE.md` from `template.file`, substituting every `{{PLACEHOLDER}}` from
  the detector's `placeholders` object. Verify no raw `{{` remains.
- **Stale CLAUDE.md** (`workspace.claudeMd.stale == "true"`): back up the existing file
  (`CLAUDE.md.bak-<date>`), then re-instantiate from the current template.
- **Old folder with host-grown content**: if a retired path holds any of
  `.env`, `.mcp.json`, `.infisical.json`, `.claude/`, `justfile`, `scripts/`, `tools/`,
  offer to **move** (not copy-delete) those into the new workspace. Show exactly what
  will move and confirm.

### 3d. Issue migration
If `localIssues.open > 0`, offer to mirror **routable + still-open** ones up to the
`devadmin` project:
- Title `[agent instructions][<agent-code>][task] <issue title>`, labels
  `agent-instructions` + `host:<slug>`, assigned to operator, state `Agent Todo`.
- **Scrub `.env`-style secrets** from the body before posting (drop lines matching
  `KEY=value` / token patterns; replace with `[redacted]`).
- Add a Linear ⇄ local back-reference: put the Linear URL in the local file and the
  local `ISSUE-id` / filename in the Linear body. The **local file stays
  authoritative** — no ongoing mirroring obligation.
Also offer the same for open GitHub Issues on this host's repo when `gh` is available
(v1 scope; per `/wrap-up`'s `gh` integration).

### 3e. Retired-folder retirement
Enumerate `retiredPaths[]` still on disk. **Never delete them here.** After content is
moved (3c), emit a checklist the user runs manually after a grace period, e.g.:

```text
# Confirm content is migrated, then retire old shapes:
rm -rf ~/dev/admin-wsl          # or:  Remove-Item -Recurse -Force D:\admin-native
```

## Step 4 — Update the routing map (EVO-54)

In the *Shared cross-host backlog: `devadmin`* section of `EVO-54`:
- Add this host to the activated host list / the host-filter note if missing
  (`host:<slug>`), and confirm the seat appears in the host's routing table with the
  correct code.
- Flip this seat's status to `online` once the EVO-53 ledger says `installed`.
- Add a dated change-log line summarizing the adoption.

Update any local routing mirror if one exists (per EVO-58 maintenance rules).

## Step 5 — Log an OK event

```bash
source "${CLAUDE_PLUGIN_ROOT}/skills/admin/scripts/log-admin-event.sh"
log_admin_event "devadmin adopted on <host> (seat <agent-code>): <what changed>" "OK"
```

(Windows: `Log-AdminEvent.ps1 -Message "..." -Level OK`.)

## Step 6 — Report

Final summary with:
- What was created/changed, each with its **URL or path** (project, label, smoke-test
  issue, workspace `CLAUDE.md`, EVO-54 edit, EVO-53 ledger).
- The **manual TODO checklist**: retired folders to `rm -rf`, tools surfaced as missing
  during the run, and anything needing human approval.
- Idempotency note: re-running this command should now report *nothing to do*.

---

## Guardrails

- **Never auto-delete a retired folder** — move content, output a checklist, the user runs `rm -rf`.
- **Never paste secrets into Linear** — scrub `.env`-style content before mirroring issues up.
- **Profile changes require confirmation** — never silently rewrite preferences from detected state.
- **Smoke test runs in the target seat** — the command cannot proxy it from another host/profile/WSL home.
- **Human approval** for publishing, customer-facing changes, destructive ops, billing, credentials, deploys.

## Notes

- This command targets only the shared `devadmin` backlog. It does **not** touch
  consumer-domain projects (WTFB Production, Twelve Pines).
- The retired-path table in `assets/devadmin/CLAUDE.md.*.template` is the migration
  spec; add a row there to teach this command a new retired shape.
