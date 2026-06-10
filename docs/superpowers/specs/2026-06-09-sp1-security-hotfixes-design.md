# SP1: Security & Functional Hotfixes — Design

**Date:** 2026-06-09
**Status:** Approved (design review with owner)
**Branch:** `fix/sp1-security-hotfixes` → PR to `main`
**Sub-project:** 1 of 5 (security/hotfixes → dead weight → schema reconciliation → CI gates → eval harness v2)

## Context

A full repo evaluation (2026-06-09) found four issues that ship in the published
marketplace plugins today:

1. **flywheel-admin publishes real infrastructure identifiers.** `references/connect.md:31-39`
   contains real OCI public IPs, Tailscale IPs, the tailnet name (also `SKILL.md:50,188`),
   hostname, username, and SSH key filenames. `SKILL.md:171` hardcodes `D:/flywheel`;
   `SKILL.md:24,50` point at a CLAUDE.md that belongs to a different repo.
2. **`scripts/profile-preflight.sh` treats its first argument as the profile path
   unconditionally** (`profile-preflight.sh:6`), so flag-first invocations fail.
   Broken call sites: `commands/deploy.md:36`, `commands/provision.md:36`,
   `commands/bootstrap.md:133`, `scripts/doctor.sh:8` (caps readiness score at 80).
   `smoke-test.sh` only tests the path-first order, which is why this was never caught.
3. **`skills/coolify/scripts/coolify-fix-dns.sh`** is not executable (violates repo rule)
   and omits `TUNNEL_HOSTNAME` from its required-vars check (line 27) despite listing it
   as required (line 36) — the script proceeds and queries Cloudflare with `name=` empty.
4. **The identifiers are already in public git history** (commit f6491fc, pushed).

Decisions made during design review:

- flywheel-admin: **genericize via `profile.servers[]`** (not placeholder-only, not private repo).
- Git history: **leave as-is; verify host security posture instead** (Tailscale 100.x IPs are
  unroutable publicly; OCI IPs are internet-facing regardless — defense is firewall + key-only SSH).
- Workflow: **branch + PR per sub-project.**

## Goals

- Zero real infrastructure identifiers in the working tree of `plugins/`.
- flywheel-admin remains published and usable by others: fleet identity resolved at
  runtime from the device profile, never from skill content.
- `profile-preflight.sh` accepts flags and the profile path in any order; `/deploy`,
  `/provision`, `/bootstrap`, and `/doctor` preflight invocations work as documented.
- `coolify-fix-dns.sh` is executable and validates all required variables.
- Security posture of the two exposed OCI hosts verified (or a verification checklist
  delivered if unreachable).

## Non-Goals (deferred to later sub-projects)

- Removing dead scripts/references, devops snapshot consolidation, `admin-workspace/`
  relocation (SP2).
- Profile schema v3/v4/v4.1 reconciliation and `servers[]` canonical schema enforcement (SP3).
- CI automation of the identifier sweep and other static gates (SP4).
- Coolify skill's missing bundled scripts / broken Path A (separate fix, out of SP1 scope).
- Git history rewrite or identifier rotation (explicitly declined).

## Design

### 1. flywheel-admin genericization

**Server entry shape** — added to `profile.servers[]` in the operator's local
`$ADMIN_ROOT/profiles/{DEVICE}.json` (local machine only; never committed to this repo):

```json
{
  "name": "acfs-relay",
  "role": "hermes-relay",
  "sshAlias": "acfs-relay",
  "provider": "oci",
  "tags": ["flywheel"],
  "notes": "Hermes relay + agent host"
}
```

- **No IPs in the entry.** Connection is `ssh <sshAlias>`; alias→IP mapping lives in
  `~/.ssh/config` (local-only by nature).
- The entry shape is documented in `flywheel-admin/references/connect.md` as the
  de-facto `servers[]` format (seed for the canonical format in SP3; the profile
  schema's `servers` is currently a free-form array, and the only documented inventory
  is devops' parallel `.env` format — that contradiction is SP2/SP3 territory and is
  not made worse here).

**File changes:**

| File | Change |
|---|---|
| `flywheel-admin/SKILL.md` | Add "Fleet Resolution" section immediately after the profile gate: enumerate fleet with a jq filter selecting `servers[]` entries tagged `flywheel`, then select host by `role`. Remove literal tailnet (lines 50, 188), `D:/flywheel` (line 171), `C:\Users\Owner` (line 50). Repoint lines 24, 50 from "CLAUDE.md in this repo" to `profile.servers[]` as the live inventory. |
| `references/connect.md` | Rewrite as a resolution-pattern doc: entry shape above, role-based lookup examples, placeholder aliases, RFC-5737 IPs (`203.0.113.x`) only. |
| `references/hermes-notes.md` | Identifier sweep: replace literal hosts/paths (lines 24, 45-46) with profile lookups. |
| `references/operator-loop.md`, `references/known-quirks.md` | Identifier sweep, same treatment. |

**One-time local migration (execution step, no repo changes):** generate `jq` commands
to add the operator's real fleet entries to the local device profile, plus stub
`~/.ssh/config` Host blocks; the operator confirms values. Real values never enter the repo.

### 2. profile-preflight.sh argument parsing (TDD)

1. **Failing test first:** add to `plugins/admin-devops/scripts/smoke-test.sh`:
   - `profile-preflight.sh --json <valid-fixture>` → expect exit 0 (currently 2).
   - Keep the existing path-first case as a regression guard.
2. **Fix:** rewrite argument handling in `profile-preflight.sh` as a single parse loop —
   flags (`--json`, any future flags) recognized at any position; the first non-flag
   argument is `PROFILE_PATH`; default path unchanged when no positional given.
3. **No call-site changes:** the four flag-first invocations become valid as-is.
4. **Downstream verification:** `scripts/doctor.sh --json` before/after — `profile_schema`
   goes 0→1 and the readiness score is no longer capped at 80 (on a machine with a valid
   profile; on CI fixtures, assert the preflight exit code path instead).

### 3. coolify-fix-dns.sh

- `chmod +x` (mode bit tracked in git).
- Add `TUNNEL_HOSTNAME` to the required-vars check at line 27.
- No other coolify changes.

### 4. Posture verification (execution step, no repo changes)

Against the two OCI hosts whose IPs were exposed, from the operator machine if reachable:

- `sshd` has `PasswordAuthentication no` (key-only).
- OCI security list / host firewall exposes only intended ports.
- Tailscale ACLs unchanged / as intended.

Results summarized in the PR description. If hosts are unreachable from the working
machine, deliver the checklist with exact commands for the operator to run.

### 5. Verification gate (before PR)

- `bash -n` on every changed script.
- `plugins/admin-devops/scripts/smoke-test.sh` passes (including the new flag-first cases).
- `plugins/admin-devops/scripts/static-qa-gates.sh` passes.
- Identifier sweep returns zero matches under `plugins/`:
  the two OCI IPs, `\b100\.(6[4-9]|[7-9][0-9]|1[01][0-9]|12[0-7])\.` (CGNAT/Tailscale range),
  the tailnet name, `WOPR3`, `C:\Users\Owner`, `D:/flywheel`.
  (These regexes are handed to SP4 as the seed for the CI secrets/identifier gate.)

## Error handling

- Fleet resolution with no matching `tags: ["flywheel"]` entries → skill instructs the
  agent to stop and run the documented profile-migration step, not to guess hosts.
- `profile-preflight.sh` with an unknown flag → non-zero exit with the existing
  JSON error envelope (current behavior for bad input preserved).
- `coolify-fix-dns.sh` missing `TUNNEL_HOSTNAME` → exits with the same required-var
  error path as the other required variables.

## Acceptance criteria

1. `grep` sweep (Section 5 regexes) over `plugins/` returns nothing.
2. A fresh reader of flywheel-admin can operate a fleet defined only in their own
   profile + ssh config; no step depends on the author's machine.
3. `bash plugins/admin-devops/scripts/profile-preflight.sh --json plugins/admin-devops/tests/fixtures/profile/valid.json`
   exits 0 with `ok:true` JSON; path-first order still works.
4. `smoke-test.sh` and `static-qa-gates.sh` both pass.
5. `test -x plugins/admin-devops/skills/coolify/scripts/coolify-fix-dns.sh` passes;
   running it without `TUNNEL_HOSTNAME` fails fast with a clear error.
6. PR description contains the posture verification results (or the checklist if
   hosts were unreachable).
