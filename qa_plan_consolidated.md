# Admin-DevOps Plugin — Consolidated QA Plan (Static Review)

Merged from four independent read-only QA reviews (`qa_plan_v1..v4.md`) of
`plugins/admin-devops`. Overlapping themes are deduplicated; every unique idea
from each source is preserved and attributed. All four reviews framed their
revisions as additions to the user-provided custom-instructions baseline:

```
# User-provided custom instructions

- keep the codebase simple
- write clean & modular code
- respect existing standards & structures
```

The consolidated revision below adds **15 engineering directives** (one per
deduped theme) to that baseline. Scope is unchanged: **read-only static
analysis — no file modifications, tests, or commits.**

---

## Consolidated revision (unified diff)

```diff
diff --git a/custom-instructions.md b/custom-instructions.md
--- a/custom-instructions.md
+++ b/custom-instructions.md
@@ -1,5 +1,23 @@
 # User-provided custom instructions
 
 - keep the codebase simple
 - write clean & modular code
 - respect existing standards & structures
+
+## Engineering directives (consolidated QA revisions)
+
+- define one machine-readable contract (routing, profile, secrets, logging) as source of truth; docs orchestrate, scripts mutate, with Bash/PowerShell parity verified
+- gate every mutating operation behind strict profile/preflight schema validation with machine-readable, fail-fast diagnostics and --fix suggestions
+- normalize errors into shared codes with remediation hints; map raw provider/API errors into the model
+- make all state changes transactional and idempotent (temp -> validate -> atomic replace -> log) with explicit lifecycle states, op/correlation IDs, and a plan/apply dry-run
+- apply resilience defaults to external operations: timeouts, bounded jittered retries, non-retryable classification, circuit breakers, and rollback guidance
+- split orchestration from providers via a thin adapter interface (discover_capabilities/validate_prereqs/provision/teardown/health_check) over a shared provider-core with capability manifests
+- generate a capability registry and validate the dependency graph (missing deps, cycles, unreachable components, trust-boundary violations)
+- maintain one generated provider/platform reference index plus a module-ownership map; keep command docs thin by linking canonical references
+- centralize secret resolution as a state machine (generated -> infisical -> vault -> env -> fail) with reason codes, audit events, policy-as-code authorization, and enforced redaction (never values)
+- emit structured JSON logs with correlation IDs (timestamp, op_id, component, action, target, status, latency_ms, error_code) alongside a human-readable layer
+- provide one health/doctor command that reports a readiness score and machine-readable status (profile/schema, secrets reachability, runtime freshness, MCP integrity, provider CLI readiness)
+- evolve /troubleshoot files into structured incident records (severity, owner, impact, timeline, runbook links) for triage-driven follow-up
+- optimize render/sync with incremental, hash-based generation and explicit cache controls; never cache secrets
+- standardize command UX with progressive disclosure and consistent sections (Prechecks/Plan/Execution/Post-steps) plus next-best-action hints
+- enforce static QA/release gates: script lint, markdown link/reference checks, command/agent/skill metadata consistency, and duplicate/obsolete artifact detection
```

---

## Themes (deduplicated)

Each theme lists *why*, the concrete *changes*, the *directive* it maps to in
the diff above, and its *source* reviews.

### Foundations — correctness & contracts

#### 1) Single machine-readable execution & script contract — *v1, v2, v3, v4*
**Why:** Behavior (routing, profile gate, secrets fallback, install policy) lives
across long markdown docs and paired `*.sh`/`*.ps1` scripts, so docs, scripts,
and agent behavior drift.
**Changes:**
- One contract spec per capability: input flags, output schema, exit-code map.
- Bash↔PowerShell parity verified by a lightweight conformance check.
- Docs orchestrate; scripts mutate state — eliminate inline state-write snippets from command markdown.
- Mark one implementation path canonical; keep the sibling wrapper minimal.

`+ define one machine-readable contract (routing, profile, secrets, logging) as source of truth; docs orchestrate, scripts mutate, with Bash/PowerShell parity verified`

#### 2) Hard profile / preflight validation gate — *v1, v2, v4*
**Why:** Workflows assume the profile exists with required keys
(`schemaVersion`, `bindings`, `consumer`, `secretsConfig`); enforcement is
documentation-driven, not gated.
**Changes:**
- Strict JSON-Schema validation before runtime rendering, MCP render/config, inventory mutation, and provision/deploy.
- Fail fast with actionable diagnostics (missing key, bad enum, malformed secret URI) and migration hints.
- `--fix-suggestions` mode for non-destructive remediation; machine-readable output for deterministic branching.

`+ gate every mutating operation behind strict profile/preflight schema validation with machine-readable, fail-fast diagnostics and --fix suggestions`

#### 3) Normalized error model + remediation taxonomy — *v1*
**Why:** Operator experience improves when errors are normalized and carry next actions.
**Changes:**
- Shared error codes (`PROFILE_MISSING`, `SECRET_UNRESOLVED`, `PROVIDER_AUTH_FAILED`, …).
- Standard remediation blocks in stderr and logs.
- Map raw provider/API errors into the normalized model.

`+ normalize errors into shared codes with remediation hints; map raw provider/API errors into the model`

### Runtime safety & reliability

#### 4) Idempotent, transactional state changes + explicit lifecycle model — *v1, v2, v4*
**Why:** Admin/devops flows are frequently interrupted and retried; non-idempotent paths and ambiguous status values raise operational risk.
**Changes:**
- Transactional pattern: write temp → validate → atomic replace → append log.
- Explicit lifecycle states (`requested`, `provisioning`, `active`, `failed`, `decommissioned`) with valid transitions.
- Operation/correlation IDs across multi-step actions; reconcile checkpoints.
- `plan` (compute/show intended changes) vs `apply` (mutate) dry-run mode.

`+ make all state changes transactional and idempotent (temp -> validate -> atomic replace -> log) with explicit lifecycle states, op/correlation IDs, and a plan/apply dry-run`

#### 5) Resilience defaults for external/provider operations — *v2, v3*
**Why:** Provider/API operations are failure-prone (network, rate limits, capacity errors); resilience is implied but not enforced at the plugin boundary.
**Changes:**
- Bounded retries with jittered backoff; explicit timeouts.
- Non-retryable error classification; short-lived circuit breaker for repeated failures.
- Documented rollback guidance for partial failures.

`+ apply resilience defaults to external operations: timeouts, bounded jittered retries, non-retryable classification, circuit breakers, and rollback guidance`

### Architecture & modularity

#### 6) Provider-core + thin provider adapters — *v1, v2, v3*
**Why:** Provider skills (OCI/Hetzner/Linode/DO/Contabo/Vultr) duplicate lifecycle concepts independently, raising maintenance cost and inconsistency.
**Changes:**
- Standard adapter interface: `discover_capabilities`, `validate_prereqs`, `provision`, `teardown`, `health_check`.
- Provider manifests: capabilities, required secrets, regions/features.
- Keep orchestration in `devops` via a shared dispatcher; delegate cloud specifics to adapters; common error taxonomy.

`+ split orchestration from providers via a thin adapter interface (discover_capabilities/validate_prereqs/provision/teardown/health_check) over a shared provider-core with capability manifests`

#### 7) Capability registry + dependency-graph validation — *v2*
**Why:** The ecosystem (skills, agents, commands, MCP entries) is broad and dependency edges break easily.
**Changes:**
- Generate a normalized registry artifact.
- Validate: missing dependencies, cycles, unreachable components, trust-boundary violations.

`+ generate a capability registry and validate the dependency graph (missing deps, cycles, unreachable components, trust-boundary violations)`

#### 8) Generated reference index + module-ownership map — *v1, v4*
**Why:** Provider/platform references overlap and drift; doc sections aren't mapped to script ownership.
**Changes:**
- One generated provider/platform index as single source of truth; thin command docs that link canonical references.
- Module-ownership map: responsibility, inputs/outputs, dependent references per script group.
- Sequence diagrams for key flows (`/library use` → post-use hook → binding write → render; provisioning → profile update → log → memory write).

`+ maintain one generated provider/platform reference index plus a module-ownership map; keep command docs thin by linking canonical references`

### Security

#### 9) Secret resolution: state machine, audit, policy-as-code, redaction — *v1, v2, v3, v4*
**Why:** The fallback chain is powerful but its behavior is inconsistent across scripts and can obscure why a lower-trust source was used; trust rules are descriptive, not executable.
**Changes:**
- Centralized resolution state machine: `generated → infisical → vault → env → fail` with standardized reason codes and retry guidance.
- Structured audit events: source selected, fallback reason, redacted key metadata (never values).
- Policy-as-code authorization: `require_primary_backend=true` for high-assurance contexts, per-consumer allow/deny, trust-boundary checks.
- Enforced, centralized redaction across logs and command reports.

`+ centralize secret resolution as a state machine (generated -> infisical -> vault -> env -> fail) with reason codes, audit events, policy-as-code authorization, and enforced redaction (never values)`

### Operability & observability

#### 10) Structured observability — JSON logs + correlation IDs — *v2*
**Why:** Logging is mandatory, but analysis is hard without structured fields.
**Changes:**
- JSON log lines: `timestamp, op_id, component, action, target, level, status, latency_ms, error_code`.
- Preserve human-readable output as a compatibility layer.
- Enables trend analysis (failure hotspots, latency outliers).

`+ emit structured JSON logs with correlation IDs (timestamp, op_id, component, action, target, status, latency_ms, error_code) alongside a human-readable layer`

#### 11) Unified health/doctor command + readiness score — *v1, v3*
**Why:** Troubleshooting knowledge exists but there's no single guided diagnostic entry point or readiness signal.
**Changes:**
- One `/doctor`-style command checking: profile presence + schema, secrets backend reachability, runtime freshness, MCP config integrity, provider CLI readiness.
- Emit a unified health/readiness score plus machine-readable JSON and a human summary.

`+ provide one health/doctor command that reports a readiness score and machine-readable status (profile/schema, secrets reachability, runtime freshness, MCP integrity, provider CLI readiness)`

#### 12) Incident-grade troubleshooting workflow — *v4*
**Why:** `/troubleshoot` is useful but reads as personal issue notes; real ops needs triage structure.
**Changes:**
- Evolve troubleshooting files into structured incident records: severity, owner, impact, timeline, runbook links.
- Support owner/severity/impact-driven triage and follow-up.

`+ evolve /troubleshoot files into structured incident records (severity, owner, impact, timeline, runbook links) for triage-driven follow-up`

### Performance & UX

#### 13) Incremental, hash-based rendering + metadata cache — *v1, v3*
**Why:** Repeated profile/secrets/config reads and full re-renders add avoidable overhead on chained commands and frequent `/library use`/profile sync.
**Changes:**
- Short-lived cache for non-secret metadata and profile parse results, invalidated on mtime/hash change.
- Incremental, hash-based render/sync that regenerates only changed outputs; explicit cache controls.
- Never cache secrets unless explicitly approved and encrypted at rest.

`+ optimize render/sync with incremental, hash-based generation and explicit cache controls; never cache secrets`

#### 14) Command UX — progressive disclosure — *v2*
**Why:** Commands are powerful but operator guidance is spread across docs, raising cognitive load and mistakes.
**Changes:**
- Concise command preflight summaries and next-best-action suggestions.
- Consistent output sections: `Prechecks`, `Plan`, `Execution`, `Post-steps`.

`+ standardize command UX with progressive disclosure and consistent sections (Prechecks/Plan/Execution/Post-steps) plus next-best-action hints`

### Process / release quality

#### 15) Static QA + release gates for plugin assets — *v2*
**Why:** A large markdown/script-heavy plugin benefits from automated checks before release (no runtime dependency needed).
**Changes:**
- Script lint rules; markdown link/reference validation.
- Command/agent/skill metadata consistency checks.
- Duplicate/obsolete artifact detection.

`+ enforce static QA/release gates: script lint, markdown link/reference checks, command/agent/skill metadata consistency, and duplicate/obsolete artifact detection`

---

## Coverage matrix

| # | Theme | v1 | v2 | v3 | v4 |
|---|---|:--:|:--:|:--:|:--:|
| 1 | Execution & script contract | ✅ | ✅ | ✅ | ✅ |
| 2 | Profile / preflight validation gate | ✅ | ✅ | | ✅ |
| 3 | Normalized error model | ✅ | | | |
| 4 | Idempotent/transactional + lifecycle | ✅ | ✅ | ✅ | ✅ |
| 5 | Resilience defaults (retry/backoff/breaker) | | ✅ | ✅ | |
| 6 | Provider-core + adapters | ✅ | ✅ | ✅ | |
| 7 | Capability registry + dep-graph validation | | ✅ | | |
| 8 | Reference index + ownership map | ✅ | | | ✅ |
| 9 | Secret resolution / policy / redaction | ✅ | ✅ | ✅ | ✅ |
| 10 | Structured JSON logs + correlation IDs | | ✅ | | |
| 11 | Health/doctor command + readiness score | ✅ | | ✅ | |
| 12 | Incident-grade troubleshooting | | | | ✅ |
| 13 | Incremental rendering + cache | ✅ | | ✅ | |
| 14 | Command UX / progressive disclosure | | ✅ | | |
| 15 | Static QA / release gates | | ✅ | | |

---

## Prioritized rollout order

Sequenced for biggest reliability gains earliest while preserving simplicity
(synthesis of the v2/v3/v4 orderings):

1. **Execution & script contract** (#1) + **profile/preflight gate** (#2) + **normalized error model** (#3) — foundation/correctness.
2. **Idempotent transactions & lifecycle** (#4) + **resilience defaults** (#5) — runtime safety.
3. **Secret resolution, policy-as-code & redaction** (#9) — security hardening.
4. **Provider-core + adapters** (#6) + **capability/dep-graph validation** (#7) — maintainability.
5. **Health/doctor command** (#11) + **structured observability** (#10) + **incident-grade troubleshooting** (#12) — operability.
6. **Incremental rendering/cache** (#13) + **command UX** (#14) — performance/UX.
7. **Reference index + ownership map** (#8) + **static QA/release gates** (#15) — documentation architecture & release quality.

---

## Checks run / scope

Read-only static analysis only — no files modified, no tests run, no commits or
PRs created. Source reviews collectively inspected:

- `plugins/admin-devops/GUIDE.md`
- `plugins/admin-devops/skills/{admin,devops}/SKILL.md`
- `plugins/admin-devops/skills/admin/assets/AGENTS.md`
- `plugins/admin-devops/commands/{bootstrap,provision,deploy,troubleshoot}.md`
- Plugin layout: commands, agents, skills, and MCP entries.
