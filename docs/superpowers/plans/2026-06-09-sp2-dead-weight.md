# SP2: Dead Weight Removal Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove dead weight from the admin-devops plugin: relocate eval artifacts out of the published plugin, consolidate 7 stale provider snapshot docs into the dedicated provider skills (delta-port audit, lossless), delete unreferenced vendored scripts and junk, and establish the committed-plans convention.

**Architecture:** Pure cleanup on branch `chore/sp2-dead-weight` → PR to `main`. No new code. Ordering avoids intermediate broken states: plans + junk + relocation + script removal first, then repoint the devops SKILL.md routing table, then delete snapshots one provider at a time (each deletion preceded by a delta-port audit with its own commit when content is ported). Existing QA gates (`smoke-test.sh`, `static-qa-gates.sh`, opt-in markdown link sweep) are the test harness.

**Tech Stack:** bash, git, grep/sed, jq not required. Spec: `docs/superpowers/specs/2026-06-09-sp2-dead-weight-design.md`.

---

## Standing security rule (applies to every task)

Never write the real infrastructure identifiers (OCI public IPs, Tailscale CGNAT IPs, tailnet name, real device hostname, Windows username) into any repo file or commit message. When a step needs them (identifier sweeps), recover them at runtime into `/tmp` per Task 1 Step 1. Pattern files live in `/tmp`, never in the repo.

---

### Task 1: Identifier-sweep and commit the plan files

The SP1 plan (`docs/superpowers/plans/2026-06-09-sp1-security-hotfixes.md`, currently untracked) and this SP2 plan get committed — after proving they contain no real identifiers.

**Files:**
- Commit: `docs/superpowers/plans/2026-06-09-sp1-security-hotfixes.md`
- Commit: `docs/superpowers/plans/2026-06-09-sp2-dead-weight.md`

- [ ] **Step 1: Build the pattern file at runtime**

```bash
cd /home/wsladmin/dev/vibe-skills
# Real identifiers live only in git history (pre-SP1 connect.md)
git show f6491fc:plugins/admin-devops/skills/flywheel-admin/references/connect.md > /tmp/sp2-old-connect.md
# IPs (filter out documentation/loopback/any ranges so RFC 5737 examples don't false-positive)
grep -oE '\b[0-9]{1,3}(\.[0-9]{1,3}){3}\b' /tmp/sp2-old-connect.md | sort -u \
  | grep -vE '^(203\.0\.113|198\.51\.100|192\.0\.2|127\.|0\.0\.0\.0)' > /tmp/sp2-patterns.txt
# Tailnet name
grep -oE '\b[a-z0-9-]+\.ts\.net\b' /tmp/sp2-old-connect.md | sort -u >> /tmp/sp2-patterns.txt
wc -l /tmp/sp2-patterns.txt
```

Expected: at least 5 lines (≥4 IPs + ≥1 tailnet host pattern).

Then print the literal patterns the SP1 spec records in its §5 verification gate (the bullet beginning "Identifier sweep returns zero matches"):

```bash
sed -n '/Identifier sweep returns zero matches/,/handed to SP4/p' docs/superpowers/specs/2026-06-09-sp1-security-hotfixes-design.md
```

Copy each backtick-quoted literal from that output (the device hostname, the `C:\...` user path, the `D:/...` path — NOT the CGNAT regex, which is handled separately below) into `/tmp/sp2-patterns.txt`, one per line, by hand or with `cat >>`. Do not echo them into any file under the repo.

- [ ] **Step 2: Sweep both plan files**

```bash
grep -Ff /tmp/sp2-patterns.txt docs/superpowers/plans/*.md; echo "fixed-string sweep exit: $?"
grep -E '\b100\.(6[4-9]|[7-9][0-9]|1[01][0-9]|12[0-7])\.' docs/superpowers/plans/*.md; echo "CGNAT sweep exit: $?"
```

Expected: no match lines; both exits `1`.

If either matches: STOP. Sanitize the offending line using the SP1 replacement conventions (placeholder hostnames, `<tailnet>.ts.net`, RFC 5737 IPs) before committing. Do not commit an unswept plan.

- [ ] **Step 3: Commit**

```bash
git add docs/superpowers/plans/2026-06-09-sp1-security-hotfixes.md docs/superpowers/plans/2026-06-09-sp2-dead-weight.md
git commit -m "$(cat <<'EOF'
docs: commit SP1 and SP2 implementation plans (plans convention)

Plans are now tracked alongside specs in docs/superpowers/plans/.
Both files pass the SP1 identifier sweep (patterns built at runtime,
never committed).

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: Junk removal + .gitignore guards

**Files:**
- Delete (untracked): `plugins/admin-devops/skills/devops/scripts/__pycache__/`
- Delete (untracked): `plugins/plugins - Shortcut.lnk`
- Modify: `.gitignore`

- [ ] **Step 1: Delete the untracked junk**

```bash
rm -rf plugins/admin-devops/skills/devops/scripts/__pycache__
rm "plugins/plugins - Shortcut.lnk"
git status --porcelain
```

Expected: neither path appears; only plan-file additions from Task 1 are gone (committed), so output is empty.

- [ ] **Step 2: Add .gitignore entries**

Append to the end of `.gitignore`:

```gitignore

# Python bytecode
__pycache__/
*.pyc

# Windows shortcuts
*.lnk
```

- [ ] **Step 3: Verify the guards work**

```bash
touch "plugins/test - Shortcut.lnk"
git check-ignore -v "plugins/test - Shortcut.lnk" && rm "plugins/test - Shortcut.lnk"
mkdir -p plugins/admin-devops/skills/devops/scripts/__pycache__ && touch plugins/admin-devops/skills/devops/scripts/__pycache__/x.pyc
git check-ignore -v plugins/admin-devops/skills/devops/scripts/__pycache__/x.pyc
rm -rf plugins/admin-devops/skills/devops/scripts/__pycache__
```

Expected: both `git check-ignore` calls print a matching `.gitignore` rule (exit 0).

- [ ] **Step 4: Commit**

```bash
git add .gitignore
git commit -m "$(cat <<'EOF'
chore: remove untracked junk; ignore __pycache__, *.pyc, *.lnk

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: Relocate eval artifacts to docs/evals/

`admin-workspace/` has no SKILL.md — it is eval output, not a skill, and currently ships in the published plugin. Pre-verified: nothing outside the directory references its paths; the static-qa-gates duplicate check scans only `artifacts/`.

**Files:**
- Move: `plugins/admin-devops/skills/admin-workspace/evals/evals.json` → `docs/evals/admin-devops/evals.json` (flattened)
- Move: `plugins/admin-devops/skills/admin-workspace/iteration-1/` → `docs/evals/admin-devops/iteration-1/`

- [ ] **Step 1: Move with git mv (preserves history)**

```bash
mkdir -p docs/evals/admin-devops
git mv plugins/admin-devops/skills/admin-workspace/evals/evals.json docs/evals/admin-devops/evals.json
git mv plugins/admin-devops/skills/admin-workspace/iteration-1 docs/evals/admin-devops/iteration-1
rmdir plugins/admin-devops/skills/admin-workspace/evals plugins/admin-devops/skills/admin-workspace
```

- [ ] **Step 2: Verify the move**

```bash
git status --porcelain | grep -c '^R '   # expect 25
test ! -e plugins/admin-devops/skills/admin-workspace && echo "old dir gone"
grep -rn "admin-workspace" plugins/ && echo "STALE REFS FOUND" || echo "no refs under plugins/"
for d in plugins/admin-devops/skills/*/; do [[ -f "$d/SKILL.md" ]] || echo "MISSING SKILL.md: $d"; done
```

Expected: `25`, `old dir gone`, `no refs under plugins/`, no MISSING lines.

- [ ] **Step 3: Verify history follows, then commit**

```bash
git commit -m "$(cat <<'EOF'
chore: relocate admin-workspace eval artifacts to docs/evals/admin-devops/

Not a skill (no SKILL.md); was shipping 25 files of eval transcripts to
every plugin consumer. docs/evals/<plugin>/ is the standing convention
for eval outputs (SP5 consumes this).

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
EOF
)"
git log --follow --oneline -- docs/evals/admin-devops/evals.json | head -3
```

Expected: log shows this commit plus pre-move history (--follow works).

---

### Task 4: Delete dead inventory scripts

Both scripts are parallel ports of the same vendored parser (jezweb/claude-skills). Pre-verified: zero invocations repo-wide; the only mention is the devops SKILL.md listing. The `.env` inventory format they validate is superseded by SP3's canonical `servers[]` schema.

**Files:**
- Delete: `plugins/admin-devops/skills/devops/scripts/agentDevopsInventory.ts`
- Delete: `plugins/admin-devops/skills/devops/scripts/agent_devops_inventory.py`
- Modify: `plugins/admin-devops/skills/devops/SKILL.md:176`

- [ ] **Step 1: Remove the scripts**

```bash
git rm plugins/admin-devops/skills/devops/scripts/agentDevopsInventory.ts plugins/admin-devops/skills/devops/scripts/agent_devops_inventory.py
```

- [ ] **Step 2: Remove the SKILL.md listing**

In `plugins/admin-devops/skills/devops/SKILL.md`, delete this line (currently line 176, first bullet under `## Scripts / References`):

```markdown
- Inventory scripts: `scripts/agentDevopsInventory.ts`, `scripts/agent_devops_inventory.py`
```

- [ ] **Step 3: Verify no dangling references**

```bash
grep -rn "agentDevopsInventory\|agent_devops_inventory" plugins/ && echo "DANGLING" || echo "clean"
ls plugins/admin-devops/skills/devops/scripts/ 2>/dev/null || echo "scripts dir empty/gone"
```

Expected: `clean`. (`scripts/` may now be empty — git drops empty dirs; `rmdir` it if it lingers on disk.)

- [ ] **Step 4: Commit**

```bash
git add plugins/admin-devops/skills/devops/SKILL.md
git commit -m "$(cat <<'EOF'
chore(devops): delete unreferenced vendored inventory validators

agentDevopsInventory.ts and agent_devops_inventory.py: zero invocations
repo-wide; vendored from jezweb/claude-skills; validate the .env
inventory format that SP3's canonical servers[] schema supersedes.
A future validator will be written against the canonical schema.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: Repoint devops SKILL.md routing to dedicated skills

Done BEFORE the snapshot deletions so no intermediate commit has a routing table pointing at deleted files.

**Files:**
- Modify: `plugins/admin-devops/skills/devops/SKILL.md:105-111` (routing table) and the `## Scripts / References` section

- [ ] **Step 1: Rewrite the routing table rows**

In `plugins/admin-devops/skills/devops/SKILL.md`, the Task Routing table currently reads:

```markdown
| OCI provisioning | references/oci.md |
| Hetzner provisioning | references/hetzner.md |
| Linode provisioning | references/linode.md |
| DigitalOcean provisioning | references/digitalocean.md |
| Contabo provisioning | references/contabo.md |
| Coolify deployment | references/coolify.md |
| KASM deployment | references/kasm.md |
```

Replace those seven rows with (matching the existing `**→ Use admin skill**` row style):

```markdown
| OCI provisioning | **→ Use oci skill** |
| Hetzner provisioning | **→ Use hetzner skill** |
| Linode provisioning | **→ Use linode skill** |
| DigitalOcean provisioning | **→ Use digital-ocean skill** |
| Contabo provisioning | **→ Use contabo skill** |
| Coolify deployment | **→ Use coolify skill** |
| KASM deployment | **→ Use kasm skill** |
```

- [ ] **Step 2: Remove the provider-references bullet**

In the `## Scripts / References` section, delete this line (the next bullet, "Provider skills: sibling skills…", already covers routing):

```markdown
- Provider references: `references/*.md` (per-provider deployment guides)
```

- [ ] **Step 3: Update the provisioning workflow pointer**

Step 3 of `## Provisioning Workflow (5 Steps)` says `Run provider workflow (see provider reference)`. Change it to:

```markdown
3. Run provider workflow (use the dedicated provider skill)
```

- [ ] **Step 4: Verify no snapshot links remain outside the snapshots**

```bash
grep -rn "references/\(oci\|hetzner\|contabo\|digitalocean\|linode\|coolify\|kasm\)\.md" plugins/ --include="*.md" | grep -v "devops/references/" && echo "STALE LINKS" || echo "clean"
```

Expected: `clean`.

- [ ] **Step 5: Commit**

```bash
git add plugins/admin-devops/skills/devops/SKILL.md
git commit -m "$(cat <<'EOF'
docs(devops): route provider work to dedicated skills, not snapshots

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
EOF
)"
```

---

## Delta-port audit procedure (Tasks 6–12)

Each snapshot opens with "_Consolidated from … on 2026-02-02_" and duplicates the dedicated skill's content as of that date. Drift since then goes both directions. The audit makes deletion provably lossless:

1. **Map the snapshot:** `grep -n '^#' <snapshot>` to list its sections. Read the snapshot in full.
2. **Map the dedicated skill:** read its `SKILL.md` and every file in its `references/` (and any other dirs, e.g. `docs/`, `templates/`).
3. **Classify every snapshot section/block:**
   - **(a) Present in the dedicated skill** (same content, possibly reworded/restructured) → no action.
   - **(b) Absent, but stale or superseded** (older command syntax, outdated facts, content the dedicated skill deliberately dropped) → drop; list it in the deletion commit message.
   - **(c) Absent and still valid** (genuinely useful content the dedicated skill never had) → port it into the dedicated skill file where it belongs (usually a `references/` doc).
   - Conflict rule: **the dedicated skill is canonical.** Where content disagrees, the snapshot version is presumed stale → (b).
4. **If any (c) content was ported:** commit the dedicated-skill edits FIRST, as their own commit (so the deletion commit stays pure):

```bash
git add plugins/admin-devops/skills/<skill>/
git commit -m "$(cat <<'EOF'
docs(<skill>): port unique content from devops snapshot

<one bullet per ported block: what and where it landed>

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
EOF
)"
```

5. **Delete the snapshot** in its own commit. The message MUST state the audit verdict — either `Audit: no unique content; all sections present in the <skill> skill or stale.` or `Audit: unique content ported in <short-sha>; remainder present or stale.` List notable (b) drops.

```bash
git rm plugins/admin-devops/skills/devops/references/<snapshot>.md
git commit -m "$(cat <<'EOF'
chore(devops): remove <snapshot>.md snapshot (consolidated 2026-02-02, stale)

Audit: <verdict line as above>

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
EOF
)"
```

The identifier sweep rule applies to ported content: if a snapshot block contains anything matching the Task 1 patterns, sanitize before porting (RFC 5737 IPs, placeholder hostnames).

---

### Task 6: Consolidate oci snapshot

**Files:**
- Audit + delete: `plugins/admin-devops/skills/devops/references/oci.md` (2590 lines)
- Possibly modify: `plugins/admin-devops/skills/oci/` (SKILL.md, references/)

- [ ] **Step 1: Run the delta-port audit procedure (above) for oci**

Known drift to check explicitly: the snapshot's "CRITICAL MUST: Secrets and .env" block near the top, and its navigation pointing at `docs/` where the dedicated skill says `references/`.

- [ ] **Step 2: Commit ported deltas (if any), per procedure step 4**
- [ ] **Step 3: Delete snapshot + commit with audit verdict, per procedure step 5**

```bash
git rm plugins/admin-devops/skills/devops/references/oci.md
```

---

### Task 7: Consolidate hetzner snapshot

**Files:**
- Audit + delete: `plugins/admin-devops/skills/devops/references/hetzner.md` (552 lines)
- Possibly modify: `plugins/admin-devops/skills/hetzner/` (SKILL.md, references/OPERATIONS.md)

- [ ] **Step 1: Run the delta-port audit procedure for hetzner**
- [ ] **Step 2: Commit ported deltas (if any)**
- [ ] **Step 3: Delete snapshot + commit with audit verdict**

```bash
git rm plugins/admin-devops/skills/devops/references/hetzner.md
```

---

### Task 8: Consolidate contabo snapshot

**Files:**
- Audit + delete: `plugins/admin-devops/skills/devops/references/contabo.md` (596 lines)
- Possibly modify: `plugins/admin-devops/skills/contabo/`

- [ ] **Step 1: Run the delta-port audit procedure for contabo**
- [ ] **Step 2: Commit ported deltas (if any)**
- [ ] **Step 3: Delete snapshot + commit with audit verdict**

```bash
git rm plugins/admin-devops/skills/devops/references/contabo.md
```

---

### Task 9: Consolidate digitalocean snapshot

**Files:**
- Audit + delete: `plugins/admin-devops/skills/devops/references/digitalocean.md` (555 lines)
- Possibly modify: `plugins/admin-devops/skills/digital-ocean/` — NOTE the directory name is `digital-ocean` (hyphenated), not `digitalocean`

- [ ] **Step 1: Run the delta-port audit procedure for digitalocean**
- [ ] **Step 2: Commit ported deltas (if any)**
- [ ] **Step 3: Delete snapshot + commit with audit verdict**

```bash
git rm plugins/admin-devops/skills/devops/references/digitalocean.md
```

---

### Task 10: Consolidate linode snapshot

**Files:**
- Audit + delete: `plugins/admin-devops/skills/devops/references/linode.md` (576 lines)
- Possibly modify: `plugins/admin-devops/skills/linode/`

- [ ] **Step 1: Run the delta-port audit procedure for linode**
- [ ] **Step 2: Commit ported deltas (if any)**
- [ ] **Step 3: Delete snapshot + commit with audit verdict**

```bash
git rm plugins/admin-devops/skills/devops/references/linode.md
```

---

### Task 11: Consolidate coolify snapshot

**Files:**
- Audit + delete: `plugins/admin-devops/skills/devops/references/coolify.md` (3207 lines — largest snapshot; budget time accordingly)
- Possibly modify: `plugins/admin-devops/skills/coolify/` (note: the sibling `coolify-cli` skill exists too — port CLI-specific deltas there if that is where equivalent content lives)

- [ ] **Step 1: Run the delta-port audit procedure for coolify**
- [ ] **Step 2: Commit ported deltas (if any)**
- [ ] **Step 3: Delete snapshot + commit with audit verdict**

```bash
git rm plugins/admin-devops/skills/devops/references/coolify.md
```

---

### Task 12: Consolidate kasm snapshot

**Files:**
- Audit + delete: `plugins/admin-devops/skills/devops/references/kasm.md` (2092 lines)
- Possibly modify: `plugins/admin-devops/skills/kasm/` (note: a sibling `kasm-admin` skill exists — check both when classifying content as present/absent)

- [ ] **Step 1: Run the delta-port audit procedure for kasm**
- [ ] **Step 2: Commit ported deltas (if any)**
- [ ] **Step 3: Delete snapshot + commit with audit verdict**

```bash
git rm plugins/admin-devops/skills/devops/references/kasm.md
```

---

### Task 13: Final verification gate + PR

**Files:** none modified — verification only, then PR.

- [ ] **Step 1: QA gates**

```bash
bash plugins/admin-devops/scripts/smoke-test.sh
bash plugins/admin-devops/scripts/static-qa-gates.sh
```

Expected: smoke `{"ok":true,"smoke":"passed"}` with 11/11 `[pass]`; gates `{"ok":true}`.

- [ ] **Step 2: Markdown link sweep**

```bash
QA_CHECK_MD_LINKS=1 bash plugins/admin-devops/scripts/static-qa-gates.sh
```

Expected: `[pass] markdown links`, or only warnings that ALSO exist on main (verify any warning by checking the same link on main with `git show main:<file>`); zero warnings referencing the deleted `references/<provider>.md` paths.

- [ ] **Step 3: Identifier sweep over the full PR diff**

Requires `/tmp/sp2-patterns.txt` from Task 1 Step 1 (rebuild it if the session restarted):

```bash
git diff main...HEAD | grep -Ff /tmp/sp2-patterns.txt; echo "fixed-string sweep exit: $?"
git diff main...HEAD | grep -E '\b100\.(6[4-9]|[7-9][0-9]|1[01][0-9]|12[0-7])\.'; echo "CGNAT sweep exit: $?"
git log main..HEAD --format=%B | grep -Ff /tmp/sp2-patterns.txt; echo "commit-message sweep exit: $?"
```

Expected: no match lines; all exits `1`.

- [ ] **Step 4: Structural checks**

```bash
grep -rEn "admin-workspace|agent_devops_inventory|agentDevopsInventory" plugins/ && echo "FAIL" || echo "clean"
ls plugins/admin-devops/skills/devops/references/
for d in plugins/admin-devops/skills/*/; do [[ -f "$d/SKILL.md" ]] || echo "MISSING SKILL.md: $d"; done
git status --porcelain
```

Expected: `clean`; references listing shows only `DEPLOYMENT_WORKFLOWS.md EXAMPLE_INVENTORY.md INVENTORY_FORMAT.md PROVIDER_DISCOVERY.md TROUBLESHOOTING.md profile-gate.md`; no MISSING lines; empty status.

- [ ] **Step 5: Push and create the PR**

```bash
git push -u origin chore/sp2-dead-weight
gh pr create --title "SP2: dead weight removal" --body "$(cat <<'EOF'
## SP2: Dead Weight Removal

Spec: `docs/superpowers/specs/2026-06-09-sp2-dead-weight-design.md` (sub-project 2 of 5)

### What changed
- **Eval artifacts relocated**: `plugins/admin-devops/skills/admin-workspace/` (25 files, no SKILL.md — was shipping to every plugin consumer) → `docs/evals/admin-devops/` via `git mv`. `docs/evals/<plugin>/` is now the standing convention for eval outputs (SP5).
- **Provider snapshots consolidated**: the 7 stale "Consolidated from … 2026-02-02" docs under `devops/references/` (~10.2K lines) audited section-by-section against the dedicated provider skills; unique deltas ported (see per-skill commits), then snapshots deleted. devops SKILL.md now routes provider work to the dedicated skills.
- **Dead scripts deleted**: `agentDevopsInventory.ts` + `agent_devops_inventory.py` (zero invocations, vendored, superseded by SP3 canonical schema).
- **Junk + guards**: `__pycache__/` and `plugins - Shortcut.lnk` removed; `.gitignore` now covers `__pycache__/`, `*.pyc`, `*.lnk`.
- **Plans convention**: implementation plans now committed to `docs/superpowers/plans/` (SP1 + SP2 plans added, identifier-sweep clean).

### Verification
- `smoke-test.sh` 11/11 · `static-qa-gates.sh` ok · markdown link sweep clean
- Identifier sweep (SP1 §5 patterns, runtime-built) over full diff + commit messages: zero matches
- Every dir under `plugins/admin-devops/skills/` has a SKILL.md
- Each snapshot deletion commit carries its audit verdict; ported deltas in separate commits

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

Fill in the actual verification results (replace claims with measured outcomes) before submitting if any step above deviated.
