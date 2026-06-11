# SP2: Dead Weight Removal — Design

**Date:** 2026-06-09
**Status:** Approved (design review with owner)
**Branch:** `chore/sp2-dead-weight` → PR to `main`
**Sub-project:** 2 of 5 (security/hotfixes → dead weight → schema reconciliation → CI gates → eval harness v2)

## Context

SP1 (PR #30, merged) deferred three dead-weight findings from the 2026-06-09 repo
evaluation, and the SP1 handoff added two more housekeeping items:

1. **`plugins/admin-devops/skills/admin-workspace/` is not a skill.** No SKILL.md —
   it is 25 files (268K) of skill-eval artifacts (A/B transcripts, grading, benchmark,
   review.html) that ship inside the published plugin to every marketplace consumer.
2. **`skills/devops/references/` carries 7 stale provider snapshots** (`oci.md`,
   `hetzner.md`, `contabo.md`, `digitalocean.md`, `linode.md`, `coolify.md`, `kasm.md`;
   ~10,200 lines). Each opens with "_Consolidated from … on 2026-02-02_" and duplicates
   the dedicated provider skill's content verbatim as of that date. Sampled drift since
   then goes in both directions. The devops SKILL.md routing table (lines 105–111)
   points at these snapshots instead of the dedicated skills.
3. **Duplicate vendored inventory validators**: `devops/scripts/agentDevopsInventory.ts`
   and `agent_devops_inventory.py` are parallel ports of the same parser from
   jezweb/claude-skills. Nothing in the repo invokes either (only a SKILL.md:176
   listing). They validate the `.env` inventory format that SP3's canonical
   `servers[]` schema supersedes.
4. **Untracked junk in the tree**: `devops/scripts/__pycache__/`,
   `plugins/plugins - Shortcut.lnk`; `.gitignore` covers neither pattern.
5. **The SP1 implementation plan** (`docs/superpowers/plans/2026-06-09-sp1-security-hotfixes.md`)
   is untracked; no convention existed for plan files.

Decisions made during design review:

- Eval artifacts: **relocate to `docs/evals/`** (not delete, not archive branch).
- Scope: **full SP2 per the SP1 spec** — relocation + junk + snapshot consolidation +
  dead scripts. The PR-#30 small follow-ups are NOT batched in; they stay on the
  follow-up list.
- Snapshots: **delta-port audit, then delete** (not delete-blind, not regeneration
  tooling) — provably lossless, same audit-value doctrine as SP1.
- Plans: **commit plan files alongside specs**, starting with the SP1 plan.

## Goals

- `plugins/admin-devops/skills/` contains only real skills (every directory has a SKILL.md).
- No provider snapshots under `devops/references/`; devops routes provider work to the
  dedicated skills; no unique snapshot content is lost.
- No unreferenced vendored scripts; no untracked junk; `.gitignore` guards the patterns.
- Plan-file convention established; SP1 plan committed (identifier-swept).

## Non-Goals (deferred)

- PR #30 review follow-ups (jq -n envelopes, coolify-fix-dns `.env` precedence, stale
  disk fact, alias drift, ASCII alignment) — remain on the follow-up list.
- `INVENTORY_FORMAT.md` / `EXAMPLE_INVENTORY.md` and the `.env`-vs-`servers[]`
  inventory contradiction — SP3.
- CI automation of any gate — SP4.
- Eval harness changes — SP5 (this PR only sets the output location convention).

## Design

### 1. Eval artifact relocation

`git mv` the contents of `plugins/admin-devops/skills/admin-workspace/` to
`docs/evals/admin-devops/`, flattening the redundant nesting:

- `admin-workspace/evals/evals.json` → `docs/evals/admin-devops/evals.json`
- `admin-workspace/iteration-1/` → `docs/evals/admin-devops/iteration-1/` (as-is)

Verified pre-design: zero references to `admin-workspace` paths elsewhere in the repo;
the static-qa-gates duplicate-content check scans only `artifacts/`. Nothing else changes.

`docs/evals/<plugin>/` becomes the standing convention for eval outputs (SP5 consumes this).

### 2. Provider snapshot consolidation (delta-port audit)

For each snapshot × dedicated skill pair — note `digitalocean.md` maps to the
`digital-ocean` directory:

| Snapshot (`devops/references/`) | Dedicated skill |
|---|---|
| `oci.md` | `skills/oci/` |
| `hetzner.md` | `skills/hetzner/` |
| `contabo.md` | `skills/contabo/` |
| `digitalocean.md` | `skills/digital-ocean/` |
| `linode.md` | `skills/linode/` |
| `coolify.md` | `skills/coolify/` |
| `kasm.md` | `skills/kasm/` |

1. **Diff** the snapshot against the dedicated skill's current content
   (SKILL.md + references/).
2. **Port** unique, still-valid deltas into the dedicated skill. Conflict rule: the
   dedicated skill is canonical — where content disagrees, the snapshot's version is
   presumed stale and dropped; only genuinely missing content is ported.
3. **Delete** the snapshot (`git rm`).

Commit structure: any delta-port lands in its own commit (or clearly separated hunks)
before the deletion commit, so reviewers can verify the deletions are content-preserving.

Then in `devops/SKILL.md`:

- Routing table (lines 105–111): each `references/<provider>.md` entry becomes
  "use the `<provider>` skill".
- Resource listing (line 177, "Provider references: `references/*.md`"): remove or
  rewrite to point at the dedicated skills.

Devops-owned references stay untouched: `DEPLOYMENT_WORKFLOWS.md`,
`PROVIDER_DISCOVERY.md`, `TROUBLESHOOTING.md`, `INVENTORY_FORMAT.md`,
`EXAMPLE_INVENTORY.md`, `profile-gate.md`.

### 3. Dead inventory scripts

- `git rm plugins/admin-devops/skills/devops/scripts/agentDevopsInventory.ts`
- `git rm plugins/admin-devops/skills/devops/scripts/agent_devops_inventory.py`
- Remove the SKILL.md:176 listing line.

If SP3 needs a validator, it is written fresh against the canonical schema.

### 4. Junk removal + .gitignore

- Delete (plain `rm -rf`, both untracked): `devops/scripts/__pycache__/`,
  `plugins/plugins - Shortcut.lnk`.
- `.gitignore` additions: `__pycache__/`, `*.pyc`, `*.lnk`.

### 5. Plans convention

- Run the SP1 identifier sweep over
  `docs/superpowers/plans/2026-06-09-sp1-security-hotfixes.md` first — patterns built
  at runtime from git history per the standing working rule (real values never enter
  the repo, including in pattern files).
- On zero matches, `git add` and commit the plan.
- Standing convention: implementation plans are committed to `docs/superpowers/plans/`
  alongside their specs.

## Error handling

- Snapshot delta that conflicts with dedicated-skill content → dedicated skill wins;
  delta dropped, noted in the commit message.
- Identifier sweep matches in the SP1 plan → stop; sanitize with the SP1 replacement
  conventions before committing (do not commit unswept).
- Broken markdown links after snapshot deletion → caught by the link sweep in the
  verification gate; fix before PR.

## Verification gate (before PR)

- `smoke-test.sh` passes (11/11) and `static-qa-gates.sh` passes.
- `QA_CHECK_MD_LINKS=1 static-qa-gates.sh` — opt-in markdown link sweep shows no new
  broken links (catches dangling `references/<provider>.md` references).
- Identifier sweep (SP1 §5 patterns, runtime-built) over the full PR diff: zero matches.
- `grep -rE "admin-workspace|agent_devops_inventory|agentDevopsInventory" plugins/`
  returns nothing.
- `git status` clean of the junk files; re-creating `__pycache__` or a `.lnk` shows
  ignored.

## Acceptance criteria

1. Every directory under `plugins/admin-devops/skills/` contains a SKILL.md.
2. `docs/evals/admin-devops/` holds the relocated artifacts; full history preserved
   (`git log --follow` works on moved files).
3. `devops/references/` contains no provider snapshots; devops SKILL.md routes provider
   work to the dedicated skills; each deletion commit is paired with its (possibly
   empty) delta-port, auditable separately.
4. Both inventory scripts gone; no dangling references to them.
5. `.gitignore` covers `__pycache__/`, `*.pyc`, `*.lnk`; tree is clean.
6. SP1 plan committed under `docs/superpowers/plans/`, identifier-sweep clean.
7. Both QA gates green; link sweep green.
