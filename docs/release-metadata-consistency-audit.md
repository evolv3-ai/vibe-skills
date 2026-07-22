# Release-Metadata Consistency Audit

**Date**: 2026-07-22
**Base commit**: 416fe08 (main)
**Scope**: Compare claims across `README.md`, `docs/SKILLS_CATALOG.md`, `CHANGELOG.md`, `CLAUDE.md`, plugin metadata, and on-disk skill/command/agent counts.
**Related issues**: EVO-126, EVO-21

---

## 1. Source Document Inventory

| Document | Status | Notes |
|---|---|---|
| `README.md` | **Present** (68 lines) | Primary public-facing description |
| `docs/SKILLS_CATALOG.md` | **Missing** | Not present on disk |
| `CHANGELOG.md` | **Missing** | Not present on disk |
| `CLAUDE.md` | **Present** | Project instructions, checked into repo |
| `.claude-plugin/plugin.json` | **Present** | Root plugin metadata |
| `.claude-plugin/marketplace.json` | **Present** | Marketplace listing |
| `plugins/admin-devops/.claude-plugin/plugin.json` | **Present** | admin-devops plugin metadata |
| `plugins/tools/.claude-plugin/plugin.json` | **Present** | tools plugin metadata |

**Observation**: Two of the three target documents (`docs/SKILLS_CATALOG.md`, `CHANGELOG.md`) do not exist. No version, release tag, or changelog content is present anywhere in the repository. Comparisons below are limited to claims that actually appear in existing documents.

---

## 2. Skill Count Comparison

### admin-devops Skills

| Source | Claimed Count | Skills Listed |
|---|---|---|
| `README.md` (lines 14-28) | 13 (table rows) | admin, devops, oci, hetzner, contabo, digital-ocean, vultr, linode, coolify, coolify-cli, kasm, openclaw, cloudflare-cli |
| `CLAUDE.md` ("13 skills" at directory tree) | 13 | Same 13 as README |
| On-disk (`plugins/admin-devops/skills/`) | **16 directories** | The 13 above **plus** flywheel-admin, hermes-agent, kasm-admin |

**MISMATCH**: Three on-disk skills are not listed in README.md or CLAUDE.md:
- `flywheel-admin/` -- Agentic Coding Flywheel fleet operations
- `hermes-agent/` -- Hermes Agent (Nous Research) deployment
- `kasm-admin/` -- KASM day-to-day operations (distinct from `kasm/` installation skill)

### tools Skills

| Source | Claimed Count | Skills Listed |
|---|---|---|
| `README.md` (lines 38-43) | 4 (table rows) | simplemem, session-scout, pi-agent-rust, iii |
| `CLAUDE.md` ("4 skills") | 4 | Same 4 |
| On-disk (`plugins/tools/skills/`) | **4 directories** | simplemem, session-scout, pi-agent-rust, iii |

**MATCH**: tools skill count is consistent across all sources.

---

## 3. Command Count Comparison

| Source | Claimed Count | Commands Listed |
|---|---|---|
| `README.md` (line 30) | "8 slash commands" header; 8 listed | `/install`, `/setup-profile`, `/mcp-bot`, `/skills-bot`, `/troubleshoot`, `/provision`, `/deploy`, `/server-status` |
| `CLAUDE.md` ("8 slash commands") | 8 | Same as README |
| On-disk (`plugins/admin-devops/commands/`) | **11 files** | adopt-devadmin, bootstrap, deploy, doctor, install, provision-agent, provision, server-status, setup-profile, troubleshoot, wrap-up |

**MISMATCH**: README/CLAUDE.md claim 8 commands; 11 exist on disk.
- Commands on disk but not in README: `adopt-devadmin`, `bootstrap`, `doctor`, `provision-agent`, `wrap-up`
- Commands in README but without a matching file: `/mcp-bot`, `/skills-bot` (no `mcp-bot.md` or `skills-bot.md` in `commands/`)

---

## 4. Agent Count Comparison

| Source | Claimed Count | Agents Listed |
|---|---|---|
| `README.md` (line 32) | "8 agents" | profile-validator, docs-agent, verify-agent, tool-installer, mcp-bot, ops-bot, server-provisioner, deployment-coordinator |
| `CLAUDE.md` ("8 agent definitions") | 8 | Same as README |
| On-disk (`plugins/admin-devops/agents/`) | **7 files** | deployment-coordinator, docs-agent, ops-bot, profile-validator, server-provisioner, tool-installer, verify-agent |

**MISMATCH**: README/CLAUDE.md claim 8 agents; 7 exist on disk.
- Agent listed in README with no file: `mcp-bot`

---

## 5. Install Steps Comparison

| Source | Install Method |
|---|---|
| `README.md` (lines 48-53) | `/plugin` marketplace add, then `/plugin install admin-devops@vibe-skills` / `tools@vibe-skills` |
| `CLAUDE.md` ("Installing from Marketplace") | Same two-step: marketplace add, then plugin install |

**MATCH**: Install steps are consistent between README.md and CLAUDE.md.

---

## 6. Marketplace Metadata Consistency

| Field | `marketplace.json` | `README.md` |
|---|---|---|
| admin-devops description | "Local machine admin, remote infrastructure provisioning, and app deployment. Profile-aware with 8 agents." | "Local machine administration, remote infrastructure provisioning, application deployment. Profile-aware 8 agents 8 slash commands." |
| tools description | "Standalone utility skills -- memory, session discovery, and development tools." | "Standalone utility skills support operations." |

**Observation**: Descriptions are thematically aligned but not identical. The marketplace.json admin-devops entry mentions "8 agents" which inherits the count mismatch (7 on disk). README adds "8 slash commands" (11 on disk).

---

## 7. Version and Release Messaging

No version number, release tag, or release/version messaging was found in any repository file. There is no `CHANGELOG.md`, no version field in any `plugin.json`, and no release notes document.

**Observation**: Version tracking is entirely absent from the repository metadata.

---

## 8. Rename Notices

No rename notices were found in any existing document. The only naming reference is the repository name `vibe-skills` which is consistent across all sources.

---

## 9. Summary of Findings

| Finding | Type | Details |
|---|---|---|
| admin-devops skill count | **Mismatch** | README/CLAUDE.md list 13; 16 exist on disk (3 unlisted) |
| tools skill count | Verified match | 4 in all sources |
| Command count | **Mismatch** | README/CLAUDE.md list 8; 11 on disk; 2 README entries have no file |
| Agent count | **Mismatch** | README/CLAUDE.md list 8; 7 on disk; `mcp-bot` has no agent file |
| Install steps | Verified match | Consistent between README and CLAUDE.md |
| Marketplace metadata | Observation | Descriptions differ in wording; inherit count mismatches |
| Version/release info | **Missing** | No version, changelog, or release metadata anywhere |
| `docs/SKILLS_CATALOG.md` | **Missing** | Document does not exist |
| `CHANGELOG.md` | **Missing** | Document does not exist |

---

## 10. Release-Readiness Checklist

- [ ] Resolve admin-devops skill count mismatch (add flywheel-admin, hermes-agent, kasm-admin to README/CLAUDE.md or explain omission)
- [ ] Resolve command count mismatch (update README from 8 to actual count; add or remove stale entries)
- [ ] Resolve agent count mismatch (add mcp-bot agent file or remove from README listing)
- [ ] Decide whether `docs/SKILLS_CATALOG.md` should be created or the reference removed
- [ ] Decide whether `CHANGELOG.md` should be created for release tracking
- [ ] Add version metadata to plugin.json files or establish a versioning strategy
- [ ] Update marketplace.json descriptions to match corrected counts

---

*This audit is observation-only. No source files, metadata, or tests were modified.*
