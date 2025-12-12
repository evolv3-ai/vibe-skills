You are performing a self-reflection on the current conversation to capture operational knowledge that would otherwise be lost when context clears.

## Purpose

Extract **operational knowledge** from this session - workflows discovered, patterns learned, tool sequences, and nuanced approaches that don't belong in commits, planning docs, or progress tracking but would be valuable for future Claude Code sessions.

**Key Insight**: This captures "how we work" not "what we built" or "what we decided".

## Command Usage

`/reflect [optional: specific-topic]`

If a topic is provided, focus reflection on that area. Otherwise, reflect on the entire session.

## When to Use

- Before context compaction or clearing
- After completing significant work or achieving a task
- When valuable learnings have accumulated
- Anytime important operational knowledge is at risk of being lost

## What This Captures (vs Other Tools)

| Knowledge Type | Existing Home | /reflect Captures? |
|----------------|---------------|-------------------|
| Code changes | Git commits | No - already saved |
| Architecture decisions | Planning docs | No - already saved |
| Progress/next steps | SESSION.md | No - already saved |
| Feature specs | /brief → docs/ | No - use /brief |
| **Workflows discovered** | ??? | **YES** |
| **Effective sequences** | ??? | **YES** |
| **Tool patterns** | ??? | **YES** |
| **Nuanced approaches** | ??? | **YES** |
| **Corrections (what worked vs didn't)** | ??? | **YES** |

## Process

### Phase 1: Self-Analysis

Review the current conversation and identify:

1. **Workflows Discovered**
   - Multi-step processes that achieved outcomes
   - Sequences that can be reused
   - "The way to do X is: step 1 → step 2 → step 3"

2. **Patterns Learned**
   - Reusable approaches to common problems
   - Best practices discovered through iteration
   - "When facing X, do Y because Z"

3. **Tool Sequences**
   - Effective tool combinations
   - Order of operations that worked well
   - "Use A then B then C for this type of task"

4. **Corrections**
   - Things that didn't work → what did work
   - Mistakes to avoid
   - "Don't do X, instead do Y"

5. **Discoveries**
   - New capabilities or features found
   - Undocumented behaviors
   - "Turns out you can do X by..."

### Phase 2: Categorize by Destination

Route each learning to the most appropriate destination:

| Knowledge Type | Destination | Criteria |
|----------------|-------------|----------|
| Universal workflow | `~/.claude/CLAUDE.md` | Applies across ALL projects |
| Project-specific | `./CLAUDE.md` | Only relevant to THIS project |
| Skill improvement | `~/.claude/skills/X/SKILL.md` | Improves a specific skill |
| Complex process | `docs/learnings.md` | Multi-step, worth documenting |
| Session context | `SESSION.md` | Temporary, this session only |
| **Repeatable process** | **Script or command** | **Will do this again, automate it** |

**Routing Heuristics**:
- If it would help ANY future project → Global CLAUDE.md
- If it's about a specific technology with a skill → That skill
- If it's complex enough to need its own section → docs/learnings.md
- If it's project-specific nuance → Project CLAUDE.md
- If it's just context for next session → SESSION.md
- **If we'll do this again → Suggest script, command, or structured workflow**

### Phase 2b: Identify Automation Opportunities

Beyond documentation, look for processes worth **operationalizing**:

**Signs a process should become a script/command:**
- We did 5+ steps manually that could be automated
- We'll need to do this again (recurring task)
- The sequence is error-prone or easy to forget
- Multiple commands need to run in specific order
- There's setup/teardown that's always the same

**Automation options to suggest:**
1. **Shell script** (`scripts/do-thing.sh`) - For CLI sequences
2. **Slash command** (`commands/thing.md`) - For Claude Code workflows
3. **npm script** (`package.json`) - For project-specific dev tasks
4. **Makefile target** - For build/deploy sequences
5. **Skill template** - If it's a reusable pattern across projects

**When suggesting automation:**
```markdown
### Automation Opportunity

**Process**: [What we did repeatedly]
**Frequency**: [How often this happens]
**Complexity**: [Number of steps, error potential]

**Suggestion**: Create [script/command/etc]
**Location**: [Where it would live]
**Benefit**: [Time saved, errors prevented]

Create this automation? [Y/n]
```

### Phase 3: Present Findings

Show the user what was found in this format:

```markdown
## Session Reflection

### Workflows Discovered
1. **[Name]**: [Description]
   → Proposed destination: [file path]

### Patterns Learned
1. **[Name]**: [Description]
   → Proposed destination: [file path]

### Tool Sequences
1. **[Tools involved]**: [When to use this sequence]
   → Proposed destination: [file path]

### Corrections Made
1. **[What didn't work → What worked]**
   → Proposed destination: [file path]

### Discoveries
1. **[What was found]**: [Why it matters]
   → Proposed destination: [file path]

### Automation Opportunities
1. **[Process name]**: [What we did manually]
   - Steps: ~[N] steps
   - Frequency: [How often we'd do this]
   → Suggestion: Create [script/command/npm script] at [location]

---

**Proposed Updates:**
- [ ] [File 1]: Add [brief description]
- [ ] [File 2]: Update [brief description]
- [ ] Create docs/learnings.md with [topics]

**Proposed Automation:**
- [ ] Create [scripts/thing.sh]: [Brief description]
- [ ] Add npm script "[name]": [Brief description]
- [ ] Create slash command [/name]: [Brief description]

Proceed? [Y/n/edit]
```

**If nothing significant found**: Report "No significant operational knowledge identified in this session that isn't already captured elsewhere." and ask if user wants to highlight something specific.

### Phase 4: Apply Updates (with confirmation)

After user confirms:

1. Read each target file
2. Find appropriate location for insertion
3. Add the knowledge in a format matching the file's style
4. For new files (like docs/learnings.md), create with proper structure
5. Show diff/summary of what was added

## Output Formats by Destination

### For ~/.claude/CLAUDE.md (Global)
Add to appropriate existing section or create new section:
```markdown
## [Section Name]

**[Pattern/Workflow Name]**: [Description]
- Step 1: ...
- Step 2: ...
- Why: [Reasoning]
```

### For Skill Files
Add to troubleshooting, patterns, or relevant section:
```markdown
### [Pattern/Tip Name]

[Description of what works]

**Why**: [Explanation]
```

### For docs/learnings.md (New or Append)
```markdown
# Project Learnings

## [Date]: [Topic]

**Context**: [What we were doing]

**Learning**: [What we discovered]

**Application**: [When/how to use this]

---
```

### For SESSION.md
Add to "Notes" or "Context" section:
```markdown
**Session Note**: [Brief learning that's relevant to next session]
```

## Examples

### Example 1: Skill Development Workflow
**Discovered**: "When creating skills, the effective sequence is: check existing patterns → copy template → fill SKILL.md → test install → verify discovery"

**Routing**: Add to `~/.claude/CLAUDE.md` under Skill Usage Protocol (universal workflow)

### Example 2: Debugging Approach
**Discovered**: "Wrangler D1 issues: always check migrations ran on BOTH local AND remote before debugging code"

**Routing**: Add to `~/.claude/skills/cloudflare-d1/SKILL.md` troubleshooting section

### Example 3: Tool Sequence
**Discovered**: "For context management: /wrap-session first, then compact, then /continue-session loads just what's needed"

**Routing**: Add to `~/.claude/CLAUDE.md` Session Handoff Protocol section

### Example 4: Project-Specific Pattern
**Discovered**: "In this project, auth tokens are validated in middleware before reaching handlers"

**Routing**: Add to `./CLAUDE.md` (project-specific)

### Example 5: Automation Opportunity
**Discovered**: "Every time we add a new skill, we: copy template, fill SKILL.md, update README, run install script, run check-metadata, test discovery"

**Routing**: Suggest creating `/create-skill` slash command or `scripts/new-skill.sh`

### Example 6: Recurring Manual Process
**Discovered**: "Before releases we always: run gitleaks, check for SESSION.md, verify .gitignore, run npm audit"

**Routing**: Suggest creating `scripts/pre-release-check.sh` or `/release` command

## Important Guidelines

- **Extract from ACTUAL conversation** - don't invent learnings
- **Focus on reusable knowledge** - avoid one-off facts
- **Preserve the "why"** - context makes learnings actionable
- **Match file style** - new content should look native
- **Be concise** - learnings should be scannable
- **Don't duplicate** - check if knowledge already exists before adding
- **Confirm before writing** - always get user approval

## Integration with Other Commands

- **After /wrap-session**: Good time to /reflect before clearing context
- **Before /continue-session**: Previous session's /reflect makes resumption smoother
- **With /brief**: /brief captures feature specs, /reflect captures process knowledge
- **Independent**: Can be used anytime during a session
