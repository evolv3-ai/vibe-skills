---
name: sub-agent-patterns
description: |
  Effective patterns for delegating tasks to parallel sub-agents in Claude Code. Covers when to delegate, prompt templates, batch sizing, output formats, and commit strategies.

  Use when: bulk operations across many items, parallel research, multi-file audits, or any repetitive task requiring judgment.
metadata:
  keywords: [sub-agent, Task tool, parallel agents, delegation, batch processing, swarm, multi-agent, bulk operations]
---

# Sub-Agent Delegation Patterns

**Status**: Production Ready ✅
**Last Updated**: 2026-01-09

Operational patterns for effective sub-agent delegation using Claude Code's Task tool.

---

## The Sweet Spot

**Best use case**: Tasks that are **repetitive but require judgment**.

```
✅ Good fit:
   - Audit 70 skills (repetitive) checking versions against docs (judgment)
   - Update 50 files (repetitive) deciding what needs changing (judgment)
   - Research 10 frameworks (repetitive) evaluating trade-offs (judgment)

❌ Poor fit:
   - Simple find-replace (no judgment needed, use sed/grep)
   - Single complex task (not repetitive, do it yourself)
   - Tasks with cross-item dependencies (agents work independently)
```

---

## Core Prompt Template

This 5-step structure works consistently:

```markdown
For each [item]:
1. Read [source file/data]
2. Verify with [external check - npm view, API, docs]
3. Check [authoritative source]
4. Evaluate/score
5. FIX issues found ← Critical: gives agent authority to act
```

**Key elements:**
- **"FIX issues found"** - Without this, agents only report. With it, they take action.
- **Exact file paths** - Prevents ambiguity and wrong-file edits
- **Output format template** - Ensures consistent, parseable reports
- **Item list** - Explicit list of what to process

---

## Batch Sizing

| Batch Size | Use When |
|------------|----------|
| 3-5 items | Complex tasks (deep research, multi-step fixes) |
| 5-8 items | Standard tasks (audits, updates, validations) |
| 8-12 items | Simple tasks (version checks, format fixes) |

**Why not more?**
- Agent context fills up
- One failure doesn't ruin entire batch
- Easier to review smaller changesets

**Parallel agents**: Launch 2-4 agents simultaneously, each with their own batch.

---

## Workflow Pattern

```
┌─────────────────────────────────────────────────────────────┐
│  1. PLAN: Identify items, divide into batches               │
│     └─ "58 skills ÷ 10 per batch = 6 agents"                │
├─────────────────────────────────────────────────────────────┤
│  2. LAUNCH: Parallel Task tool calls with identical prompts │
│     └─ Same template, different item lists                  │
├─────────────────────────────────────────────────────────────┤
│  3. WAIT: Agents work in parallel                           │
│     └─ Read → Verify → Check → Edit → Report                │
├─────────────────────────────────────────────────────────────┤
│  4. REVIEW: Check agent reports and file changes            │
│     └─ git status, spot-check diffs                         │
├─────────────────────────────────────────────────────────────┤
│  5. COMMIT: Batch changes with meaningful changelog         │
│     └─ One commit per tier/category, not per agent          │
└─────────────────────────────────────────────────────────────┘
```

---

## Prompt Templates

### Audit/Validation Pattern

```markdown
Deep audit these [N] [items]. For each:

1. Read the [source file] from [path]
2. Verify [versions/data] with [command or API]
3. Check official [docs/source] for accuracy
4. Score 1-10 and note any issues
5. FIX issues found directly in the file

Items to audit:
- [item-1]
- [item-2]
- [item-3]

For each item, create a summary with:
- Score and status (PASS/NEEDS_UPDATE)
- Issues found
- Fixes applied
- Files modified

Working directory: [absolute path]
```

### Bulk Update Pattern

```markdown
Update these [N] [items] to [new standard/format]. For each:

1. Read the current file at [path pattern]
2. Identify what needs changing
3. Apply the update following this pattern:
   [show example of correct format]
4. Verify the change is valid
5. Report what was changed

Items to update:
- [item-1]
- [item-2]
- [item-3]

Output format:
| Item | Status | Changes Made |
|------|--------|--------------|

Working directory: [absolute path]
```

### Research/Comparison Pattern

```markdown
Research these [N] [options/frameworks/tools]. For each:

1. Check official documentation at [URL pattern or search]
2. Find current version and recent changes
3. Identify key features relevant to [use case]
4. Note any gotchas, limitations, or known issues
5. Rate suitability for [specific need] (1-10)

Options to research:
- [option-1]
- [option-2]
- [option-3]

Output format:
## [Option Name]
- **Version**: X.Y.Z
- **Key Features**: ...
- **Limitations**: ...
- **Suitability Score**: X/10
- **Recommendation**: ...
```

---

## Output Format Design

Structure agent reports for easy scanning:

```markdown
## [Category] Audit Summary

| Item | Score | Status | Issues | Fixed |
|------|-------|--------|--------|-------|
| item-1 | 9.5/10 | PASS | 1 | Yes |
| item-2 | 8.0/10 | NEEDS_UPDATE | 2 | Yes |

### Detailed Findings

#### item-1 (Score: 9.5/10)
**Issues Found**: [description]
**Fix Applied**: [what was changed]
**File**: [path]
```

---

## Commit Strategy

**Agents don't commit** - they only edit files. This is by design:

| Agent Does | Human Does |
|------------|------------|
| Research & verify | Review changes |
| Edit files | Spot-check diffs |
| Score & report | git add/commit |
| Create summaries | Write changelog |

**Why?**
- Review before commit catches agent errors
- Batch multiple agents into meaningful commits
- Clean commit history (not 50 tiny commits)
- Human decides commit message/grouping

**Commit pattern:**
```bash
git add [files] && git commit -m "$(cat <<'EOF'
[type]([scope]): [summary]

[Batch 1 changes]
[Batch 2 changes]
[Batch 3 changes]

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

---

## Error Handling

### When One Agent Fails

1. Check the error message
2. Decide: retry that batch OR skip and continue
3. Don't let one failure block the whole operation

### When Agent Makes Wrong Change

1. `git diff [file]` to see what changed
2. `git checkout -- [file]` to revert
3. Re-run with more specific instructions

### When Agents Conflict

Rare (agents work on different items), but if it happens:
1. Check which agent's change is correct
2. Manually resolve or re-run one agent

---

## Real Examples

### Example 1: Skill Audits (This Session)

**Task**: Audit 25 Cloudflare + Frontend skills

**Approach**:
- 3 batches of 5 Cloudflare skills (parallel)
- 2 batches of 5 Frontend skills (parallel)
- Same prompt template for all

**Results**:
- 25 skills audited in ~5 minutes
- Found: outdated versions, wrong limits, missing features
- All fixed automatically

### Example 2: Description Optimization

**Task**: Trim 58 skill descriptions from 400+ chars to 250-350

**Approach**:
- 6 batches of ~10 skills each (parallel)
- Prompt: "Trim description, move keywords to metadata.keywords"

**Results**:
- 58 skills processed in ~3 minutes
- 0 skills over 350 chars (was 58)

### Example 3: Multi-Site Updates (flare-sites)

**Task**: Update configuration across 12 client sites

**Approach**:
- 3 batches of 4 sites
- Each agent: read config, apply update, verify

**Results**:
- All sites updated consistently
- Changes reviewed and committed in batches

---

## Signs a Task Fits This Pattern

✅ **Use sub-agents when:**
- Same steps repeated for 5+ items
- Each item requires judgment (not just transformation)
- Items are independent (no cross-item dependencies)
- Clear success criteria exists
- Authoritative source available to verify against

❌ **Don't use sub-agents when:**
- Items depend on each other's results
- Requires creative/subjective decisions
- Single complex task (use regular conversation)
- Simple transformation (use sed/grep/scripts)
- Needs human input mid-process

---

## Quick Reference

```
Batch size:     5-8 items per agent (adjust for complexity)
Parallel:       2-4 agents simultaneously
Prompt:         5-step template (read → verify → check → evaluate → FIX)
Output:         Structured tables + detailed findings
Commit:         Human reviews, batches, commits with changelog
Errors:         Retry failed batch OR skip and continue
```

---

**Last Updated**: 2026-01-09
