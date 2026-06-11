# SP1: Security & Functional Hotfixes — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove all real infrastructure identifiers from `plugins/`, fix `profile-preflight.sh` flag-order parsing, fix `coolify-fix-dns.sh` (executable bit + `TUNNEL_HOSTNAME` validation), and verify the security posture of the two exposed hosts.

**Architecture:** flywheel-admin is genericized so the fleet is resolved at runtime from `profile.servers[]` (entries tagged `flywheel`) plus the operator's `~/.ssh/config` — no IPs, tailnet names, hostnames, or user paths in skill content. Script fixes are TDD'd through `smoke-test.sh`. Two execution-only tasks (local profile migration, posture verification) touch the operator machine, never the repo.

**Tech Stack:** bash, jq, sed, git, gh CLI. No new dependencies.

**Spec:** `docs/superpowers/specs/2026-06-09-sp1-security-hotfixes-design.md`
**Branch:** `fix/sp1-security-hotfixes` (already checked out) → PR to `main`

---

## CRITICAL RULE FOR THIS PLAN

**Never write the real identifiers into any repo file — including this plan, commit messages, or the PR body.** That is the bug we are fixing. The sensitive values are: two OCI public IPs, two Tailscale CGNAT IPs, and the tailnet name. Where a task needs them (local-only ssh config, sweep patterns), it recovers them at runtime from git history:

```bash
git show f6491fc:plugins/admin-devops/skills/flywheel-admin/references/connect.md > /tmp/sp1-old-connect.md
```

The milder identifiers the spec spells out explicitly — `WOPR3` (hostname), `C:\Users\Owner` (username path), `D:/flywheel` (path) — may appear in this plan and in *search/sed commands*, but must not survive in `plugins/` content.

**Replacement conventions (use consistently):**

| Real value | Replacement |
|---|---|
| `WOPR3` / `wopr3` | `DEVICE01` / `device01` |
| `Owner` in `Users/Owner`, `Users\Owner` paths | `user` (matches existing `/home/user` convention) |
| tailnet `*.ts.net` literal | `<tailnet>.ts.net` in prose; `your tailnet` in sentences |
| OCI public IPs | `203.0.113.10` / `203.0.113.20` (RFC 5737) |
| Tailscale CGNAT IPs | do not show example CGNAT IPs at all (a literal address in the CGNAT range would trip the sweep regex); describe as "Tailscale-assigned address" |
| `D:/flywheel/.claude/skills` | `$SKILLS_SRC` / `<skills-bundle>` placeholder |
| Author's ssh aliases `flywheel-1-oci`, `flywheel-2-oci` as *literal* fleet enumeration | placeholder aliases `flywheel-1`, `flywheel-2`, `flywheel-N` (aliases are non-sensitive, but docs must not imply the author's 2-host fleet is *your* fleet) |

Out of scope (deliberate, do not fix): the device name `wsl-hermes` (not on the spec's sweep list), `DELTABOT`, `kasm-hetzner-02`, `Larry's PC`, forward-slash `Users/Owner` in files this plan doesn't already touch — **except** Task 7 sweeps `Users/Owner` everywhere because it is mechanical and the same username. Git history rewrite: explicitly declined in the spec.

---

## File Structure

| File | Action | Responsibility |
|---|---|---|
| `plugins/admin-devops/scripts/profile-preflight.sh` | Modify | Arg parse loop: flags at any position |
| `plugins/admin-devops/scripts/smoke-test.sh` | Modify | New test cases (preflight flag-first, coolify-fix-dns) |
| `plugins/admin-devops/skills/coolify/scripts/coolify-fix-dns.sh` | Modify + chmod | Add `TUNNEL_HOSTNAME` to required-vars check |
| `plugins/admin-devops/skills/flywheel-admin/references/connect.md` | Rewrite | Resolution-pattern doc: entry shape, lookups, migration recipe |
| `plugins/admin-devops/skills/flywheel-admin/SKILL.md` | Modify | Fleet Resolution section; remove tailnet/paths; repoint CLAUDE.md refs |
| `plugins/admin-devops/skills/flywheel-admin/references/hermes-notes.md` | Rewrite | Identifier-free Hermes operator notes |
| `plugins/admin-devops/skills/flywheel-admin/references/known-quirks.md` | Modify | Genericize MagicDNS section |
| ~14 other files under `plugins/admin-devops/` | sed sweep | Replace `WOPR3`/`wopr3`/`Users/Owner`/`Users\Owner` (Task 7 computes the exact list) |
| Operator machine: device profile + `~/.ssh/config` | Local only | Fleet entries + Host blocks (Task 8 — never committed) |
| `/tmp/sp1-posture.md` | Local only | Posture verification results for the PR body (Task 9) |

No call-site changes to `commands/deploy.md`, `commands/provision.md`, `commands/bootstrap.md`, `scripts/doctor.sh` — their existing flag-first invocations become valid once Task 1 lands.

---

### Task 1: `profile-preflight.sh` accepts flags in any position (TDD)

The bug: `profile-preflight.sh:6` takes `$1` as the profile path unconditionally, so `profile-preflight.sh --json` treats `--json` as a path → `PROFILE_MISSING` → exit 2. This breaks 4 call sites and caps `doctor.sh` readiness at 80.

**Files:**
- Test: `plugins/admin-devops/scripts/smoke-test.sh`
- Modify: `plugins/admin-devops/scripts/profile-preflight.sh`

- [ ] **Step 1: Record the current (broken) doctor output for the before/after demo**

Run:
```bash
cd /home/wsladmin/dev/vibe-skills
bash plugins/admin-devops/scripts/doctor.sh --json
```
Expected (the bug, verified 2026-06-09):
```json
{"readiness_score":80,"checks":{"profile_schema":0,"secrets_reachability":1,"runtime_freshness":1,"mcp_integrity":1,"provider_cli_readiness":1}}
```

- [ ] **Step 2: Write the failing tests**

In `plugins/admin-devops/scripts/smoke-test.sh`, after the existing line 20 (`expect_exit "preflight invalid -> 3" ...`), insert:

```bash
expect_exit "preflight flag-first valid -> 0"   0 "$BASE/scripts/profile-preflight.sh" --json "$BASE/tests/fixtures/profile/valid.json"
expect_exit "preflight flag-first invalid -> 3" 3 "$BASE/scripts/profile-preflight.sh" --json "$BASE/tests/fixtures/profile/invalid.json"
expect_exit "preflight unknown flag -> 2"       2 "$BASE/scripts/profile-preflight.sh" --bogus "$BASE/tests/fixtures/profile/valid.json"
```

- [ ] **Step 3: Run the smoke test to verify the new cases fail**

Run: `bash plugins/admin-devops/scripts/smoke-test.sh`
Expected: `[FAIL] preflight flag-first valid -> 0 expected=0 got=2` and `[FAIL] preflight flag-first invalid -> 3 expected=3 got=2`. (The unknown-flag case passes already — it is a regression guard.) Overall exit 1.

- [ ] **Step 4: Rewrite the argument handling**

Replace the **entire contents** of `plugins/admin-devops/scripts/profile-preflight.sh` with:

```bash
#!/usr/bin/env bash
# Strict profile preflight gate (QA #2). cwd-independent paths.
# Flags and the profile path may appear in any order.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE="$(cd "$SCRIPT_DIR/.." && pwd)"
PROFILE_PATH=""
MODE="text"
FIX=0
for arg in "$@"; do
  case "$arg" in
    --json) MODE="json" ;;
    --fix-suggestions) FIX=1 ;;
    --*)
      printf '{"ok":false,"error_code":"UNKNOWN_FLAG","flag":"%s"}\n' "$arg"
      exit 2
      ;;
    *)
      if [[ -z "$PROFILE_PATH" ]]; then PROFILE_PATH="$arg"; fi
      ;;
  esac
done
PROFILE_PATH="${PROFILE_PATH:-${ADMIN_PROFILE_PATH:-$BASE/tests/fixtures/profile/valid.json}}"
if [[ ! -f "$PROFILE_PATH" ]]; then
  if [[ "$MODE" == "json" ]]; then
    printf '{"ok":false,"error_code":"PROFILE_MISSING","profile":"%s"}\n' "$PROFILE_PATH"
  else
    echo "PROFILE_MISSING: $PROFILE_PATH"
  fi
  exit 2
fi
python3 - "$PROFILE_PATH" "$MODE" "$FIX" <<'PY'
import json, sys
profile_path, mode, fix = sys.argv[1], sys.argv[2], sys.argv[3]
try:
    p = json.load(open(profile_path))
except Exception as e:
    out = {"ok": False, "error_code": "PROFILE_INVALID", "message": f"parse error: {e}"}
    print(json.dumps(out) if mode == "json" else f"PROFILE_INVALID: {e}")
    sys.exit(3)
required = ["schemaVersion", "bindings", "consumer", "secretsConfig"]
missing = [k for k in required if k not in p]
sc = p.get("secretsConfig", {})
if "secretsConfig" not in missing and "primaryBackend" not in sc:
    missing.append("secretsConfig.primaryBackend")
if missing:
    out = {"ok": False, "error_code": "PROFILE_INVALID", "missing": missing}
    if fix == "1":
        out["fix_suggestions"] = [f"Add '{k}' to profile" for k in missing]
    print(json.dumps(out) if mode == "json" else f"PROFILE_INVALID: missing {', '.join(missing)}")
    sys.exit(3)
out = {"ok": True, "profile": profile_path}
print(json.dumps(out) if mode == "json" else "OK: profile valid")
PY
```

The Python block is byte-identical to the current one — only the bash arg handling changes. Behavior preserved: no positional arg → `ADMIN_PROFILE_PATH` env → fixture default; first non-flag arg is the profile path; unknown `--*` flag → JSON error envelope, exit 2 (the spec's required error behavior; previously unknown flags also exited 2, via the PROFILE_MISSING path).

- [ ] **Step 5: Run the smoke test to verify all cases pass**

Run: `bash plugins/admin-devops/scripts/smoke-test.sh`
Expected: every line `[pass]`, final line `{"ok":true,"smoke":"passed"}`, exit 0.

- [ ] **Step 6: Verify the downstream doctor fix**

Run: `bash plugins/admin-devops/scripts/doctor.sh --json`
Expected: `"profile_schema":1` and `"readiness_score":100` (this machine has a valid fixture and all four other check files — confirmed during planning; if any other check were 0 the score differs, but `profile_schema` MUST be 1).

Also run the spec's acceptance command verbatim:
```bash
bash plugins/admin-devops/scripts/profile-preflight.sh --json plugins/admin-devops/tests/fixtures/profile/valid.json
```
Expected: exit 0, output `{"ok": true, "profile": "plugins/admin-devops/tests/fixtures/profile/valid.json"}`.

- [ ] **Step 7: Syntax-check and commit**

```bash
bash -n plugins/admin-devops/scripts/profile-preflight.sh
bash -n plugins/admin-devops/scripts/smoke-test.sh
git add plugins/admin-devops/scripts/profile-preflight.sh plugins/admin-devops/scripts/smoke-test.sh
git commit -m "fix: profile-preflight.sh accepts flags in any argument position

Flag-first invocations (/deploy, /provision, /bootstrap, doctor.sh) previously
failed with PROFILE_MISSING because \$1 was taken as the profile path
unconditionally. doctor.sh readiness was capped at 80 (profile_schema:0).
Unknown flags now fail fast with an UNKNOWN_FLAG JSON envelope (exit 2).
Smoke test covers flag-first valid/invalid and unknown-flag ordering."
```

---

### Task 2: `coolify-fix-dns.sh` — executable bit + `TUNNEL_HOSTNAME` validation (TDD)

The bugs: the script is mode 644 (repo rule: scripts must be executable), and the required-vars check at line 27 omits `TUNNEL_HOSTNAME` even though the error text at line 36 lists it as required — so the script proceeds and queries Cloudflare with `name=` empty.

**Files:**
- Test: `plugins/admin-devops/scripts/smoke-test.sh`
- Modify: `plugins/admin-devops/skills/coolify/scripts/coolify-fix-dns.sh`

- [ ] **Step 1: Write the failing test**

In `plugins/admin-devops/scripts/smoke-test.sh`, insert this block **before** the final `if (( fail == 0 )); then` (after the `provider-core health` line):

```bash
# coolify-fix-dns must fail fast (no network) when TUNNEL_HOSTNAME is missing,
# and must be executable (repo rule).
DNS_SCRIPT="$BASE/skills/coolify/scripts/coolify-fix-dns.sh"
dns_out=$(env CLOUDFLARE_API_TOKEN=x CLOUDFLARE_ZONE_ID=x DNS_RECORD_ID=x TUNNEL_ID=x \
  CLOUDFLARE_ACCOUNT_ID=x TUNNEL_HOSTNAME="" timeout 15 bash "$DNS_SCRIPT" 2>&1)
dns_rc=$?
if [[ $dns_rc -eq 1 && "$dns_out" == *"Missing required environment variables"* ]]; then
  echo "  [pass] coolify-fix-dns missing TUNNEL_HOSTNAME -> 1"
else
  echo "  [FAIL] coolify-fix-dns missing TUNNEL_HOSTNAME expected=1+message got=$dns_rc"
  fail=1
fi
if [[ -x "$DNS_SCRIPT" ]]; then
  echo "  [pass] coolify-fix-dns executable"
else
  echo "  [FAIL] coolify-fix-dns not executable"
  fail=1
fi
```

(`env` with dummy values keeps the check hermetic post-fix — validation exits before any `curl`. `timeout 15` bounds the one pre-fix RED run, which may attempt network calls.)

- [ ] **Step 2: Run the smoke test to verify both new checks fail**

Run: `bash plugins/admin-devops/scripts/smoke-test.sh`
Expected: `[FAIL] coolify-fix-dns missing TUNNEL_HOSTNAME ...` (pre-fix the script passes validation and proceeds — whatever exit it produces, the "Missing required" message is absent) and `[FAIL] coolify-fix-dns not executable`. Exit 1.

- [ ] **Step 3: Fix the script**

In `plugins/admin-devops/skills/coolify/scripts/coolify-fix-dns.sh` line 27, replace:

```bash
if [ -z "$CLOUDFLARE_API_TOKEN" ] || [ -z "$CLOUDFLARE_ZONE_ID" ] || [ -z "$DNS_RECORD_ID" ] || [ -z "$TUNNEL_ID" ] || [ -z "$CLOUDFLARE_ACCOUNT_ID" ]; then
```

with:

```bash
if [ -z "$CLOUDFLARE_API_TOKEN" ] || [ -z "$CLOUDFLARE_ZONE_ID" ] || [ -z "$DNS_RECORD_ID" ] || [ -z "$TUNNEL_ID" ] || [ -z "$CLOUDFLARE_ACCOUNT_ID" ] || [ -z "$TUNNEL_HOSTNAME" ]; then
```

Then set the executable bit (git tracks the mode change):

```bash
chmod +x plugins/admin-devops/skills/coolify/scripts/coolify-fix-dns.sh
```

- [ ] **Step 4: Run the smoke test to verify it passes**

Run: `bash plugins/admin-devops/scripts/smoke-test.sh`
Expected: all `[pass]`, `{"ok":true,"smoke":"passed"}`, exit 0. Also verify directly: `test -x plugins/admin-devops/skills/coolify/scripts/coolify-fix-dns.sh && echo OK` → `OK`.

- [ ] **Step 5: Syntax-check and commit**

```bash
bash -n plugins/admin-devops/skills/coolify/scripts/coolify-fix-dns.sh
bash -n plugins/admin-devops/scripts/smoke-test.sh
git add plugins/admin-devops/skills/coolify/scripts/coolify-fix-dns.sh plugins/admin-devops/scripts/smoke-test.sh
git commit -m "fix: coolify-fix-dns.sh validates TUNNEL_HOSTNAME and is executable

The required-vars check omitted TUNNEL_HOSTNAME despite listing it as
required, so the script proceeded to query Cloudflare with name= empty.
Smoke test asserts fail-fast (exit 1 + clear error, no network) and the
executable bit."
```

---

### Task 3: Rewrite `references/connect.md` as a resolution-pattern doc

This file currently contains both OCI public IPs, both Tailscale IPs, the tailnet name (×3), the Windows hostname, and the username path. It becomes the canonical doc for the `servers[]` entry shape + ssh-config pattern (the seed for SP3's canonical schema).

**Files:**
- Rewrite: `plugins/admin-devops/skills/flywheel-admin/references/connect.md`

- [ ] **Step 1: Confirm the file is currently dirty (RED)**

```bash
grep -cE '\b100\.(6[4-9]|[7-9][0-9]|1[01][0-9]|12[0-7])\.|\.ts\.net|WOPR3|Users.Owner|\b129\.' plugins/admin-devops/skills/flywheel-admin/references/connect.md
```
Expected: non-zero count.

- [ ] **Step 2: Replace the entire file contents with:**

````markdown
# Connecting to Flywheels

Connection identity lives in two **local-only** places — never in this skill:

1. **Your device profile** (`$ADMIN_ROOT/profiles/$ADMIN_DEVICE.json`) — *which* hosts
   exist: one `servers[]` entry per flywheel, tagged `flywheel`.
2. **Your `~/.ssh/config`** — *how* to reach each one: a `Host` block per `sshAlias`.

If either is missing, run the one-time migration below before using any other part of
the flywheel-admin skill. **Never guess hostnames, IPs, or aliases.**

## The `servers[]` entry shape

```json
{
  "name": "flywheel-1",
  "role": "swarm-host",
  "sshAlias": "flywheel-1",
  "provider": "oci",
  "tags": ["flywheel"],
  "notes": "Ubuntu 24.04 LTS; watch disk headroom"
}
```

- **No IPs in the entry.** Addresses live only in `~/.ssh/config`.
- `sshAlias` is the contract: every command in this skill is `ssh <sshAlias> '...'`.
- `role` distinguishes hosts (`swarm-host`, `hermes-relay`, …).
- `notes` carries per-host facts (OS version, disk headroom, installed extras such as
  PostgreSQL or beads_rust) — the facts this skill's "pick a target" guidance reads.
- `tags` must include `"flywheel"` — fleet enumeration filters on it.

## Resolving the fleet

```bash
source ~/.admin/.env   # ADMIN_ROOT, ADMIN_DEVICE
PROFILE="$ADMIN_ROOT/profiles/$ADMIN_DEVICE.json"

# Enumerate all flywheel hosts: name, role, sshAlias, notes
jq -r '.servers[]? | select((.tags // []) | index("flywheel"))
       | [.name, .role, .sshAlias, (.notes // "")] | @tsv' "$PROFILE"

# Select one host by role
HOST=$(jq -r '.servers[]? | select((.tags // []) | index("flywheel"))
              | select(.role == "swarm-host") | .sshAlias' "$PROFILE" | head -n1)
ssh "$HOST" 'acfs doctor'
```

No matching entries → **STOP** and run the migration below. Do not fall back to
hardcoded hosts.

## Registering your fleet (one-time migration)

Per host, append a `servers[]` entry (back the profile up first):

```bash
cp "$PROFILE" "$PROFILE.bak.$(date +%s)"
jq '.servers = ((.servers // []) + [{
  "name": "flywheel-1",
  "role": "swarm-host",
  "sshAlias": "flywheel-1",
  "provider": "oci",
  "tags": ["flywheel"],
  "notes": "Ubuntu 24.04 LTS"
}])' "$PROFILE" > "$PROFILE.tmp" && mv "$PROFILE.tmp" "$PROFILE"
```

Then add a `Host` block per alias to `~/.ssh/config` (WSL/Linux) or
`%USERPROFILE%\.ssh\config` (Windows):

```
Host flywheel-1
  HostName flywheel-1.<tailnet>.ts.net    # Tailscale MagicDNS (preferred)
  User ubuntu
  IdentityFile ~/.ssh/id_ed25519_flywheel

Host flywheel-1-public                     # fallback when Tailscale is down
  HostName 203.0.113.10                    # the host's public IP
  User ubuntu
  IdentityFile ~/.ssh/id_ed25519_flywheel
```

`203.0.113.x` is RFC 5737 documentation space — substitute your real values. Keep the
`-public` fallback aliases if your provider exposes a public IP.

## Cross-surface execution

```powershell
# From PowerShell (aliases from %USERPROFILE%\.ssh\config)
ssh flywheel-1 'acfs doctor'

# Force WSL from PowerShell
wsl -e bash -c "ssh flywheel-1 'acfs doctor'"
```

```bash
# From WSL / Linux / Hermes
ssh flywheel-1 'acfs doctor'
```

Each operator surface keeps its own key and ssh config; they work independently.

## VSCode Remote-SSH

Use Microsoft's `ms-vscode-remote.remote-ssh` extension. The Tailscale extension is
unnecessary on a tailnet-joined host.

1. F1 → `Remote-SSH: Connect to Host…`
2. Pick an alias (auto-loaded from your ssh config)
3. Server installs in ~10 s, new window opens

## Sanity check

If `ssh <alias> 'hostname'` works, you're in. If not, in order:

1. `tailscale status` — is the operator on the tailnet?
2. `ping <alias>` — is MagicDNS resolving the flywheel?
3. Try the `-public` alias — is it just MagicDNS that's broken?
4. Check Tailscale admin: https://login.tailscale.com/admin/machines
````

- [ ] **Step 3: Verify the file is clean (GREEN)**

```bash
grep -nE '\b100\.(6[4-9]|[7-9][0-9]|1[01][0-9]|12[0-7])\.|WOPR3|Users.Owner|\b129\.[0-9]+\.[0-9]+\.[0-9]+\b' plugins/admin-devops/skills/flywheel-admin/references/connect.md
grep -oE '[a-z0-9-]+\.ts\.net' plugins/admin-devops/skills/flywheel-admin/references/connect.md | sort -u
```
Expected: first command prints nothing (exit 1); second prints only `<tailnet>.ts.net`.

- [ ] **Step 4: Commit**

```bash
git add plugins/admin-devops/skills/flywheel-admin/references/connect.md
git commit -m "fix: rewrite flywheel-admin connect.md without real infrastructure identifiers

Now a resolution-pattern doc: servers[] entry shape, role-based jq lookups,
one-time migration recipe, placeholder aliases, RFC 5737 example IPs only.
Fleet identity resolves from the operator's device profile + ssh config."
```

---

### Task 4: Genericize `flywheel-admin/SKILL.md`

Six targeted edits. The current file has the tailnet literal at lines 50 and 188, `D:/flywheel` at line 171, `C:\Users\Owner` at line 50, and "read CLAUDE.md for the fleet" at lines 22–25, 50, and 193. **The old text for Edits B and E contains the tailnet literal — do not copy it anywhere; locate by the anchors given.**

**Files:**
- Modify: `plugins/admin-devops/skills/flywheel-admin/SKILL.md`

- [ ] **Step 1: Edit A — repoint the "Read first" blockquote (lines 22–25)**

Replace the blockquote that begins `> **Read first.** Always read the project's \`CLAUDE.md\`` (4 lines) with:

```markdown
> **Read first.** Always resolve the fleet from your device profile before acting —
> `profile.servers[]` (entries tagged `flywheel`) is the source of truth for the current
> fleet inventory, SSH aliases, and per-host notes. This skill captures the *patterns*;
> your profile captures *today's state*. See **Fleet Resolution** below.
```

- [ ] **Step 2: Edit B — replace the `## Fleet` section with `## Fleet Resolution`**

Replace everything from the line `## Fleet` (line 48) through the line `[references/connect.md](references/connect.md).` (line 59 — the paragraph ending the section, just before `## The Operator Loop`) with:

````markdown
## Fleet Resolution

The fleet is defined in your device profile (`$ADMIN_ROOT/profiles/$ADMIN_DEVICE.json`),
never in this skill. Each fleet host is a `servers[]` entry tagged `flywheel`:

```json
{
  "name": "flywheel-1",
  "role": "swarm-host",
  "sshAlias": "flywheel-1",
  "provider": "oci",
  "tags": ["flywheel"],
  "notes": "Ubuntu 24.04 LTS; watch disk headroom"
}
```

Enumerate the fleet, then pick a host by `role` (or by `notes` when several qualify):

```bash
source ~/.admin/.env   # ADMIN_ROOT, ADMIN_DEVICE
PROFILE="$ADMIN_ROOT/profiles/$ADMIN_DEVICE.json"

# All flywheel hosts: name, role, sshAlias, notes
jq -r '.servers[]? | select((.tags // []) | index("flywheel"))
       | [.name, .role, .sshAlias, (.notes // "")] | @tsv' "$PROFILE"

# One host by role
HOST=$(jq -r '.servers[]? | select((.tags // []) | index("flywheel"))
              | select(.role == "swarm-host") | .sshAlias' "$PROFILE" | head -n1)
ssh "$HOST" 'acfs doctor'
```

**No matching entries? STOP.** Do not guess hostnames or fall back to hardcoded values —
run the one-time migration in [references/connect.md](references/connect.md) to register
your fleet, then retry.

Connection is always `ssh <sshAlias>`; the alias→address mapping lives in your
`~/.ssh/config` (see [references/connect.md](references/connect.md) for every operator
surface and the public-IP fallback pattern). Throughout this skill, `flywheel-N` (and
`flywheel-N-oci` in older examples) stands for a resolved `sshAlias` from *your* profile.
````

- [ ] **Step 3: Edit C — genericize the Discover snippet**

In `### 1. Discover`, replace the code block containing two literal `ssh flywheel-1-oci ...` / `ssh flywheel-2-oci ...` health-snapshot lines with:

```bash
# Health snapshot per host (run in parallel if you can)
for h in $(jq -r '.servers[]? | select((.tags // []) | index("flywheel")) | .sshAlias' "$PROFILE"); do
  ssh "$h" 'uptime; free -h | head -2; df -h / | tail -1; acfs doctor 2>&1 | tail -5; ntm list'
done
```

- [ ] **Step 4: Edit D — genericize the "Pick a target" table**

In `### 2. Pick a target`, replace the 3-row table referencing flywheel-1/flywheel-2 host facts (and keep the "If both are loaded…" sentence after it) with:

```markdown
Pick by the `role` and `notes` fields of your `servers[]` entries — per-host facts
(OS version, disk headroom, installed extras like PostgreSQL or beads_rust) belong in
`notes`, not in this skill. Rules of thumb:

| Need | Pick |
|------|------|
| Stable base for a long-running swarm | the host whose `notes` mark it LTS/stable |
| Newest stack features | the host whose `notes` mark the newer stack |
| Two independent swarms in parallel | one host each |
```

- [ ] **Step 5: Edit E — remove `D:/flywheel` from Skill Mirror (line 171)**

Replace the line:

```bash
scp -r "D:/flywheel/.claude/skills/." flywheel-N-oci:~/skills-staging/
```

with:

```bash
# SKILLS_SRC = your canonical local skills bundle (e.g. <repo>/.claude/skills)
scp -r "$SKILLS_SRC/." flywheel-N-oci:~/skills-staging/
```

- [ ] **Step 6: Edit F — provisioning step 3 (line 188): remove the tailnet literal**

The line is step `3.` of "Provisioning a New Flywheel" and names the tailnet. Replace the whole list item with:

```markdown
3. Join your tailnet (`sudo tailscale up --authkey=...`).
```

- [ ] **Step 7: Edit G — provisioning step 8 (line 193): repoint from CLAUDE.md**

Replace:

```markdown
8. Add the new host to `CLAUDE.md` and to `~/.ssh/config` on Windows and wsl-hermes.
```

with:

```markdown
8. Add the new host to `profile.servers[]` (tagged `flywheel`) and a `Host` block to
   `~/.ssh/config` on each operator surface (see [references/connect.md](references/connect.md)).
```

- [ ] **Step 8: Verify the file is clean (GREEN)**

```bash
grep -nE '\.ts\.net|D:[/\\]flywheel|Users.Owner|WOPR3|CLAUDE\.md' plugins/admin-devops/skills/flywheel-admin/SKILL.md
```
Expected: no output (exit 1). (`CLAUDE.md` must be gone too — both fleet-inventory references were repointed.)

- [ ] **Step 9: Commit**

```bash
git add plugins/admin-devops/skills/flywheel-admin/SKILL.md
git commit -m "fix: flywheel-admin resolves fleet from profile.servers[], not hardcoded hosts

Adds Fleet Resolution section (jq filter on tags:[flywheel], role-based
selection, stop-and-migrate on empty). Removes tailnet literal, Windows
user path, and D:/flywheel; repoints fleet inventory from CLAUDE.md to
the device profile."
```

---

### Task 5: Rewrite `references/hermes-notes.md` without identifiers

Current file hardcodes `D:\flywheel\.claude\skills\...`, `/mnt/d/flywheel/...`, and `C:\Users\Owner\.ssh\...` (lines 9, 15–17, 24, 28–33, 45–46).

**Files:**
- Rewrite: `plugins/admin-devops/skills/flywheel-admin/references/hermes-notes.md`

- [ ] **Step 1: Replace the entire file contents with:**

````markdown
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
````

- [ ] **Step 2: Verify clean**

```bash
grep -nE 'D:[/\\]flywheel|/mnt/d/flywheel|Users.Owner|WOPR3|\.ts\.net' plugins/admin-devops/skills/flywheel-admin/references/hermes-notes.md
```
Expected: no output (exit 1).

- [ ] **Step 3: Commit**

```bash
git add plugins/admin-devops/skills/flywheel-admin/references/hermes-notes.md
git commit -m "fix: remove hardcoded operator paths from flywheel-admin hermes-notes"
```

---

### Task 6: `known-quirks.md` sweep + verify `operator-loop.md` is clean

`known-quirks.md` names the tailnet twice (the `## Tailscale / Networking` section heading and body, lines 102–104). `operator-loop.md` was verified clean during planning — re-verify, no edits expected.

**Files:**
- Modify: `plugins/admin-devops/skills/flywheel-admin/references/known-quirks.md`
- Verify only: `plugins/admin-devops/skills/flywheel-admin/references/operator-loop.md`

- [ ] **Step 1: Edit the MagicDNS quirk section**

In `known-quirks.md` under `## Tailscale / Networking`, the first subsection's heading and first paragraph name the tailnet. Replace the heading line and the paragraph (everything down to the ```bash fence) with:

```markdown
### MagicDNS resolution

On a working tailnet, MagicDNS resolves each flywheel's machine name directly — the
`sshAlias` Host blocks point at `<host>.<tailnet>.ts.net`. If `ssh <alias>` fails:
```

(The bash block underneath — `tailscale status` / `ping` / `ssh ...-public` — stays; if its comments reference specific aliases, leave them: `flywheel-N` forms are placeholders.)

- [ ] **Step 2: Verify both files clean**

```bash
grep -nE '\.ts\.net[^)]|WOPR3|Users.Owner|D:[/\\]flywheel' plugins/admin-devops/skills/flywheel-admin/references/known-quirks.md | grep -v '<tailnet>'
grep -nE '\.ts\.net|WOPR3|Users.Owner|D:[/\\]flywheel|\b100\.(6[4-9]|[7-9][0-9]|1[01][0-9]|12[0-7])\.' plugins/admin-devops/skills/flywheel-admin/references/operator-loop.md
```
Expected: no output from either.

- [ ] **Step 3: Commit**

```bash
git add plugins/admin-devops/skills/flywheel-admin/references/known-quirks.md
git commit -m "fix: genericize tailnet references in flywheel-admin known-quirks"
```

---

### Task 7: Mechanical identifier sweep across the rest of `plugins/`

Beyond flywheel-admin, the device hostname and username path appear in ~14 files (verified during planning): `GUIDE.md`, `agents/ops-bot.md`, `skills/admin/references/{device-profiles,profile-gate,remote-profile,library-integration,vault-guide,wsl,secrets-architecture}.md`, `skills/devops/references/profile-gate.md`, `skills/admin/assets/env-template`, `skills/admin/scripts/{post-skill-issue.ps1,Test-AdminProfile.ps1}`, and 6 eval artifacts under `skills/admin-workspace/iteration-1/` (transcripts, grading.json, review.html — historical eval output slated for relocation in SP2; a mechanical substitution is acceptable). All occurrences are doc examples — `WOPR3`/`wopr3` → `DEVICE01`/`device01` and `Users/Owner`-style paths → `Users/user` are semantics-preserving. This task also sweeps forward-slash `/mnt/c/Users/Owner` variants (same username, same fix) even though the spec's gate regex only names the backslash form.

**Files:**
- Modify: every file under `plugins/` still matching the patterns (computed, not hardcoded — Tasks 3–6 already cleaned flywheel-admin)

- [ ] **Step 1: List the dirty files (RED)**

```bash
cd /home/wsladmin/dev/vibe-skills
grep -rlEI 'WOPR3|wopr3|Users[/\\]+Owner' plugins/ --exclude-dir=__pycache__ | sort
```
Expected: ~14 files, none under `skills/flywheel-admin/`.

- [ ] **Step 2: Apply the substitutions**

```bash
cd /home/wsladmin/dev/vibe-skills
grep -rlEI 'WOPR3|wopr3|Users[/\\]+Owner' plugins/ --exclude-dir=__pycache__ | while IFS= read -r f; do
  sed -i \
    -e 's/Users\\\\Owner/Users\\\\user/g' \
    -e 's/Users\\Owner/Users\\user/g' \
    -e 's|Users/Owner|Users/user|g' \
    -e 's/WOPR3/DEVICE01/g' \
    -e 's/wopr3/device01/g' \
    "$f"
done
```

(The three `Users` rules cover doubled-backslash JSON examples, single-backslash Windows paths, and forward-slash `/mnt/c/...` paths. `wopr3` catches `INFISICAL_MACHINE_IDENTITY=wopr3-operator` → `device01-operator`.)

- [ ] **Step 3: Verify clean (GREEN) and spot-check semantics**

```bash
grep -rnEI 'WOPR3|wopr3|Users[/\\]+Owner' plugins/ --exclude-dir=__pycache__
```
Expected: no output (exit 1).

Spot-check three files to confirm examples still read sensibly:
```bash
sed -n '305,310p' plugins/admin-devops/GUIDE.md                                  # table row now DEVICE01
sed -n '30,45p' plugins/admin-devops/skills/admin/references/profile-gate.md     # ADMIN_DEVICE=DEVICE01, device01-operator
sed -n '38,42p' plugins/admin-devops/skills/admin/references/device-profiles.md  # C:\Users\user\.admin
```

- [ ] **Step 4: Commit**

```bash
cd /home/wsladmin/dev/vibe-skills
git add -A plugins/
git status --short   # confirm only intended .md/.json/.html/.ps1/env-template files staged; nothing from __pycache__ or '*.lnk'
git commit -m "fix: replace real device hostname and username with placeholders across plugins/

WOPR3 -> DEVICE01 (and wopr3 -> device01) in docs, agent prompts, env
template, and admin-workspace eval artifacts; Users/Owner and
Users\\Owner path examples -> Users/user. Doc examples only; no
functional content depends on the literal values."
```

If `git status` shows `plugins/plugins - Shortcut.lnk` or `__pycache__/` as untracked, leave them untracked (they are pre-existing junk, out of SP1 scope — note for SP2).

---

### Task 8: Local profile migration (execution step — NO repo changes)

Registers the operator's real fleet in the local device profile and ssh config, so the genericized skill keeps working on this machine. Real values come from git history and local files; **nothing in this task is committed**.

**Files (operator machine only):**
- Modify: the device profile under `$ADMIN_ROOT/profiles/` (backed up first)
- Modify: `~/.ssh/config` (backed up first, append-only, marker comments)

- [ ] **Step 1: Resolve the local profile path**

```bash
source ~/.admin/.env   # defines ADMIN_ROOT, ADMIN_DEVICE
ROOT="$ADMIN_ROOT"
# The satellite may store a Windows-style path (X:/...); convert for WSL
if [[ "$ROOT" =~ ^([A-Za-z]):[/\\](.*)$ ]]; then
  drive="${BASH_REMATCH[1],,}"; rest="${BASH_REMATCH[2]//\\//}"
  ROOT="/mnt/$drive/$rest"
fi
PROFILE="$ROOT/profiles/$ADMIN_DEVICE.json"
test -f "$PROFILE" && echo "profile: $PROFILE" || echo "PROFILE NOT FOUND — record in /tmp/sp1-posture.md and skip to Task 9"
```

(Verified during planning: the satellite exists and the profile resolves under `/mnt/c/...`.)

- [ ] **Step 2: Back up, then add the two fleet entries (idempotent)**

```bash
cp "$PROFILE" "$PROFILE.bak.sp1-$(date +%Y%m%d)"
add_entry() {  # add_entry <name> <alias> <notes>
  if jq -e --arg a "$2" '.servers[]? | select(.sshAlias == $a)' "$PROFILE" >/dev/null; then
    echo "exists: $2"
  else
    jq --arg n "$1" --arg a "$2" --arg notes "$3" \
      '.servers = ((.servers // []) + [{"name":$n,"role":"swarm-host","sshAlias":$a,"provider":"oci","tags":["flywheel"],"notes":$notes}])' \
      "$PROFILE" > "$PROFILE.tmp" && mv "$PROFILE.tmp" "$PROFILE"
    echo "added: $2"
  fi
}
add_entry flywheel-1 flywheel-1-oci "Ubuntu 24.04 LTS; lower disk headroom - watch it"
add_entry flywheel-2 flywheel-2-oci "Ubuntu 25.10; PostgreSQL, beads_rust, meta_skill"
jq '.servers[] | select((.tags // []) | index("flywheel")) | {name, role, sshAlias}' "$PROFILE"
```

Expected final output: both entries listed. (The real aliases `flywheel-N-oci` are non-sensitive and live only in this local profile.)

- [ ] **Step 3: Add ssh config Host blocks if missing (real values from git history, local-only)**

```bash
cd /home/wsladmin/dev/vibe-skills
git show f6491fc:plugins/admin-devops/skills/flywheel-admin/references/connect.md > /tmp/sp1-old-connect.md
TAILNET=$(grep -oE '[a-z0-9-]+\.ts\.net' /tmp/sp1-old-connect.md | head -1)
PUB1=$(grep -oE '\b129\.[0-9]+\.[0-9]+\.[0-9]+\b' /tmp/sp1-old-connect.md | sed -n 1p)
PUB2=$(grep -oE '\b129\.[0-9]+\.[0-9]+\.[0-9]+\b' /tmp/sp1-old-connect.md | sed -n 2p)
KEY=~/.ssh/id_rsa; test -f "$KEY" || echo "WARN: $KEY missing — note in /tmp/sp1-posture.md"

if ! grep -qs '^Host flywheel-1-oci' ~/.ssh/config; then
  touch ~/.ssh/config && cp ~/.ssh/config ~/.ssh/config.bak.sp1
  cat >> ~/.ssh/config <<EOF

# --- SP1 flywheel fleet ($(date +%F)) — pairs with profile.servers[] ---
Host flywheel-1-oci
  HostName flywheel-1-oci.$TAILNET
  User ubuntu
  IdentityFile $KEY
Host flywheel-2-oci
  HostName flywheel-2-oci.$TAILNET
  User ubuntu
  IdentityFile $KEY
Host flywheel-1-public
  HostName $PUB1
  User ubuntu
  IdentityFile $KEY
Host flywheel-2-public
  HostName $PUB2
  User ubuntu
  IdentityFile $KEY
EOF
  chmod 600 ~/.ssh/config
  echo "appended 4 Host blocks"
else
  echo "Host blocks already present"
fi
```

- [ ] **Step 4: Sanity-check resolution end-to-end (the acceptance-criterion-2 path)**

```bash
jq -r '.servers[]? | select((.tags // []) | index("flywheel")) | .sshAlias' "$PROFILE"
ssh -G flywheel-1-oci | grep -E '^(hostname|user|identityfile) '
```
Expected: two aliases printed; `ssh -G` shows the MagicDNS FQDN, `user ubuntu`, and the key path. Confirm `git status` shows **no repo changes** from this task.

---

### Task 9: Posture verification of the exposed hosts (execution step — NO repo changes)

The two OCI hosts' public and Tailscale IPs are in public git history (left there by decision). Verify their defenses; write results to `/tmp/sp1-posture.md` for the PR body.

- [ ] **Step 1: Initialize the results file**

```bash
cat > /tmp/sp1-posture.md <<'EOF'
## Posture verification (SP1 §4)

Identifiers for two OCI hosts are in public git history (commit f6491fc; history
rewrite explicitly declined). Verified defenses below. Tailscale CGNAT addresses
are not publicly routable; the public IPs are internet-facing regardless of this
repo, so the defense is key-only SSH + firewall.
EOF
```

- [ ] **Step 2: Run the checks per host (reachable path)**

```bash
for h in flywheel-1-oci flywheel-2-oci; do
  if ssh -o BatchMode=yes -o ConnectTimeout=8 "$h" true 2>/dev/null; then
    {
      echo; echo "### $h — reachable, checked $(date +%F)"
      echo '- sshd auth:'
      ssh "$h" 'sudo sshd -T 2>/dev/null | grep -iE "^(passwordauthentication|kbdinteractiveauthentication|permitrootlogin) " || sudo grep -rihE "^(PasswordAuthentication|PermitRootLogin)" /etc/ssh/sshd_config /etc/ssh/sshd_config.d/ 2>/dev/null' | sed 's/^/    /'
      echo '- non-loopback listeners:'
      ssh "$h" "sudo ss -tlnp | awk 'NR==1 || \$4 !~ /127\\.0\\.0\\.1|\\[::1\\]/'" | sed 's/^/    /'
      echo '- host firewall (INPUT policy + first rules):'
      ssh "$h" 'sudo iptables -S INPUT 2>/dev/null | head -25' | sed 's/^/    /'
      echo '- tailscale:'
      ssh "$h" 'tailscale status --peers=false 2>/dev/null | head -3' | sed 's/^/    /'
    } >> /tmp/sp1-posture.md
  else
    echo -e "\n### $h — UNREACHABLE from operator machine" >> /tmp/sp1-posture.md
  fi
done
cat /tmp/sp1-posture.md
```

**PASS condition:** `passwordauthentication no` on both hosts; INPUT policy default-deny (or explicit REJECT tail) with only intended ports (22, anything deliberately published); no surprise non-loopback listeners.

- [ ] **Step 3: If either host was unreachable, append the operator checklist instead**

```bash
cat >> /tmp/sp1-posture.md <<'EOF'

### Operator checklist (run per host; ssh <alias> first)
1. Key-only SSH:  `sudo sshd -T | grep -iE '^(passwordauthentication|permitrootlogin) '`
   → expect `passwordauthentication no`.
2. Listeners:     `sudo ss -tlnp` → only intended services bound to non-loopback.
3. Host firewall: `sudo iptables -S INPUT` → default-deny / REJECT tail, port 22 + intended ports only.
4. OCI security list (console): Networking → VCN → subnet → Security Lists →
   ingress rules expose only intended ports to 0.0.0.0/0.
5. Tailscale ACLs (https://login.tailscale.com/admin/acls): unchanged / as intended.
EOF
```

- [ ] **Step 4: Distill a 3–6 line pass/fail summary**

Append a `### Summary` section to `/tmp/sp1-posture.md` with one verdict line per check (e.g. "Key-only SSH: PASS on both hosts"). **The PR body gets the summary + checklist only — never raw `ss`/`iptables` output or IPs** (a public PR enumerating open ports would be a fresh leak). Confirm `git status` is clean.

---

### Task 10: Full verification gate (spec §5 + acceptance criteria)

- [ ] **Step 1: `bash -n` every changed script**

```bash
cd /home/wsladmin/dev/vibe-skills
bash -n plugins/admin-devops/scripts/profile-preflight.sh
bash -n plugins/admin-devops/scripts/smoke-test.sh
bash -n plugins/admin-devops/skills/coolify/scripts/coolify-fix-dns.sh
echo "syntax OK"
```

- [ ] **Step 2: Smoke test and static QA gates**

```bash
bash plugins/admin-devops/scripts/smoke-test.sh        # expect {"ok":true,"smoke":"passed"}, exit 0
bash plugins/admin-devops/scripts/static-qa-gates.sh   # expect {"ok":true}, exit 0
```

- [ ] **Step 3: Identifier sweep — zero matches over tracked files in `plugins/`**

Build the pattern file with the sensitive values pulled from history (never typed into the repo), then sweep:

```bash
cd /home/wsladmin/dev/vibe-skills
cat > /tmp/sp1-patterns.txt <<'EOF'
100\.(6[4-9]|[7-9][0-9]|1[01][0-9]|12[0-7])\.
WOPR3
C:\\Users\\Owner
D:/flywheel
D:\\flywheel
EOF
git show f6491fc:plugins/admin-devops/skills/flywheel-admin/references/connect.md > /tmp/sp1-old-connect.md
grep -oE '\b129\.[0-9]+\.[0-9]+\.[0-9]+\b' /tmp/sp1-old-connect.md | sort -u >> /tmp/sp1-patterns.txt
grep -oE '[a-z0-9-]+\.ts\.net' /tmp/sp1-old-connect.md | sed 's/\.ts\.net//' | sort -u >> /tmp/sp1-patterns.txt

git grep -nE -f /tmp/sp1-patterns.txt -- plugins/ && echo "SWEEP FAILED" || echo "sweep clean"
```

Expected: `sweep clean` (git grep exits 1 — no matches). These patterns are the seed for SP4's CI gate; note that in the PR body.

- [ ] **Step 4: Walk the acceptance criteria**

```bash
# AC3: flag-first preflight
bash plugins/admin-devops/scripts/profile-preflight.sh --json plugins/admin-devops/tests/fixtures/profile/valid.json; echo "exit=$?"
# expect: {"ok": true, ...} and exit=0
bash plugins/admin-devops/scripts/profile-preflight.sh plugins/admin-devops/tests/fixtures/profile/valid.json --json; echo "exit=$?"
# expect: path-first still works, exit=0

# AC5: coolify script
test -x plugins/admin-devops/skills/coolify/scripts/coolify-fix-dns.sh && echo "AC5 executable: PASS"
```

AC1 = Step 3 above. AC2 = Task 8 Step 4 (fleet operable from profile + ssh config alone). AC4 = Step 2 above. AC6 = Task 11 (posture summary in PR body).

- [ ] **Step 5: Commit anything the gate flushed out (should be nothing)**

If Steps 1–4 required fixes, fix, re-run the failing step, and commit with `fix: address SP1 verification gate findings`. Otherwise no commit.

---

### Task 11: Push branch and open the PR

- [ ] **Step 1: Review the branch state**

```bash
cd /home/wsladmin/dev/vibe-skills
git log --oneline main..fix/sp1-security-hotfixes
git status --short   # expect only untracked pre-existing junk (__pycache__, *.lnk)
```
Expected: the 6–7 task commits from this plan on top of `95d5a55`.

- [ ] **Step 2: Push and create the PR**

```bash
git push -u origin fix/sp1-security-hotfixes
gh pr create --base main --title "SP1: security & functional hotfixes" --body-file /tmp/sp1-pr-body.md
```

Compose `/tmp/sp1-pr-body.md` first:

```markdown
## SP1: Security & Functional Hotfixes

Spec: `docs/superpowers/specs/2026-06-09-sp1-security-hotfixes-design.md` (sub-project 1 of 5)

### What changed
- **flywheel-admin genericized**: fleet identity now resolves at runtime from
  `profile.servers[]` (entries tagged `flywheel`) + the operator's `~/.ssh/config`.
  connect.md rewritten as a resolution-pattern doc (placeholder aliases, RFC 5737 IPs).
  No real IPs, tailnet name, hostnames, or user paths remain anywhere under `plugins/`.
- **profile-preflight.sh**: flags accepted in any position; `/deploy`, `/provision`,
  `/bootstrap`, and `doctor.sh` flag-first invocations now work. doctor readiness
  `profile_schema` 0→1 (score was capped at 80). Unknown flags → `UNKNOWN_FLAG` JSON, exit 2.
- **coolify-fix-dns.sh**: executable bit set; `TUNNEL_HOSTNAME` added to required-vars
  check (previously queried Cloudflare with `name=` empty).
- Device hostname / username placeholders (`DEVICE01`, `Users/user`) substituted across
  docs and eval artifacts.

### Verification
- `smoke-test.sh` ✅ (incl. new flag-first + coolify cases) · `static-qa-gates.sh` ✅
- Identifier sweep over `plugins/` (tracked files): **zero matches** for the spec §5
  patterns. These regexes are handed to SP4 as the CI-gate seed.
- Git history deliberately **not** rewritten (design decision); defense verified below.

### Posture verification
<paste the Summary + checklist sections from /tmp/sp1-posture.md — verdicts only, no raw port/firewall dumps>

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

- [ ] **Step 3: Confirm**

```bash
gh pr view --web=false
```
Expected: PR open against `main`, body includes posture summary (AC6 ✅).

---

## Self-Review (performed while writing this plan)

- **Spec coverage:** §1 flywheel genericization → Tasks 3–6 (+ entry shape, fleet-resolution jq, stop-on-empty error handling) and Task 8 (local migration). §2 preflight TDD → Task 1 (incl. unknown-flag envelope and doctor before/after). §3 coolify → Task 2. §4 posture → Task 9. §5 verification gate → Task 10. Branch+PR workflow → Task 11. Non-goals respected (no dead-weight removal, no schema reconciliation, no CI automation, no history rewrite).
- **Beyond-spec deltas, made deliberately:** (a) the sweep must clean ~14 non-flywheel files (GUIDE.md, ops-bot.md, admin references, eval artifacts) — the spec's design section doesn't enumerate them but acceptance criterion 1 requires it (Task 7); (b) forward-slash `Users/Owner` variants are swept too (same username, mechanical); (c) `wsl-hermes` and `DELTABOT` left alone (not on the spec's list).
- **Placeholder scan:** every code step has complete code; no TBDs. The only "fill in" values are the sensitive identifiers, which are *recovered from git history at runtime by design* — putting them in this plan would republish them.
- **Type/name consistency:** `servers[]` entry fields (`name`, `role`, `sshAlias`, `provider`, `tags`, `notes`) identical across Task 3 (connect.md), Task 4 (SKILL.md), and Task 8 (migration jq). Replacement tokens (`DEVICE01`, `Users/user`, `<tailnet>.ts.net`, `203.0.113.x`, `$SKILLS_SRC`) consistent across Tasks 3–7.
