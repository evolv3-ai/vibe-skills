---
name: memory-manager
description: >
  Manage CLAUDE.md memory hierarchy across repositories. Audit for bloat, split
  oversized files into topic-specific sub-files, create directory-level CLAUDE.md
  files, and verify the hierarchy loads correctly. Use when CLAUDE.md exceeds
  100 lines, when a directory needs its own context, or when project memory
  needs restructuring.
compatibility: claude-code-only
---

# Memory Manager

Audit and restructure the CLAUDE.md memory hierarchy in a repository. Produces a clean, well-organised set of CLAUDE.md files that follow size guidelines and progressive disclosure.

## How CLAUDE.md Loading Works

Claude Code loads CLAUDE.md from the current working directory AND all parent directories. Deeper files take precedence. This means:

- `~/CLAUDE.md` — global context (always loaded)
- `~/project/CLAUDE.md` — project context
- `~/project/src/CLAUDE.md` — src-specific context
- `~/project/src/api/CLAUDE.md` — api-specific context

All four load when working in `src/api/`. Use this hierarchy to keep each file small and focused.

## Workflow

### Step 1: Audit current state

Run the audit script to get a size report:

```bash
python3 skills/memory-manager/scripts/audit_memory.py [repo-path]
```

This reports:
- All CLAUDE.md files with line counts
- Files exceeding size targets
- Directories that might benefit from their own CLAUDE.md
- Content that could be split into topic files

### Step 2: Identify splits

For each oversized CLAUDE.md, identify sections that can become:

1. **Directory-level CLAUDE.md** — context specific to that directory
2. **Topic files in `.claude/rules/`** — correction rules and patterns
3. **Deletable content** — duplicates parent, states the obvious, or Claude already knows

**Size targets:**
- Root CLAUDE.md: 50–150 lines (project identity, key commands, architecture)
- Sub-directory CLAUDE.md: 20–50 lines (integrations, gotchas, commands)
- Topic files in rules/: 20–80 lines each

### Step 3: Create directory-level files

For directories with external integrations, non-obvious config, or common gotchas, create a focused CLAUDE.md:

```markdown
# [Component Name]

## Key Integrations
- **Service X**: endpoint, auth method, secret location

## Commands
npm run deploy
npm run test

## Gotchas
- Always run migrations before testing
```

**Don't create one when:**
- Parent CLAUDE.md already covers it
- The directory is simple/self-explanatory
- Content would be fewer than 10 lines

### Step 4: Restructure root CLAUDE.md

The root CLAUDE.md should contain ONLY:

- Project identity (what this is, who owns it)
- Architecture overview (stack, key directories)
- Essential commands (build, deploy, test)
- Critical rules (things that break if forgotten)
- Links to deeper docs

Everything else moves to sub-directory files or `.claude/rules/`.

### Step 5: Verify

Re-run the audit script to confirm all files are within targets. Test by working in various directories and checking Claude has the right context.

## Guidelines

### What belongs in root CLAUDE.md
- Project name, purpose, owner
- Tech stack summary
- Key commands (build, deploy, test)
- Critical "never do X" rules
- Directory structure overview

### What belongs in sub-directory CLAUDE.md
- External service integrations for that component
- Non-obvious configuration
- Directory-specific commands
- Common gotchas when working in that area

### What belongs in .claude/rules/
- Correction rules (bridging training cutoff)
- Coding patterns specific to this project
- Error prevention patterns

### What to delete
- Content Claude already knows from training
- Verbose explanations of standard tools
- Changelogs and version history
- Duplicated content from parent files

## Delegation

For large repos, delegate the audit to a sub-agent to preserve main context:

```
Task(subagent_type: "general-purpose",
  prompt: "Run python3 skills/memory-manager/scripts/audit_memory.py /path/to/repo
           and summarise the findings. List files over target size and suggest splits.")
```

The agent absorbs the verbose output and returns only actionable recommendations.

## Scripts

- `scripts/audit_memory.py` — Scan repo for CLAUDE.md files, report sizes, suggest improvements
