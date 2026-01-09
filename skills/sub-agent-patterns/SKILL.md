---
name: sub-agent-patterns
description: |
  Comprehensive guide to sub-agents in Claude Code: built-in agents (Explore, Plan, general-purpose), custom agent creation, configuration, and delegation patterns.

  Use when: creating custom sub-agents, delegating bulk operations, parallel research, understanding built-in agents, or configuring agent tools/models.
metadata:
  keywords: [sub-agent, Task tool, parallel agents, delegation, batch processing, swarm, multi-agent, bulk operations, .claude/agents, Explore agent, Plan agent, general-purpose agent, resumable agents]
---

# Sub-Agents in Claude Code

**Status**: Production Ready ✅
**Last Updated**: 2026-01-09
**Source**: https://code.claude.com/docs/en/sub-agents

Sub-agents are specialized AI assistants that Claude Code can delegate tasks to. Each sub-agent has its own context window, configurable tools, and custom system prompt.

---

## Built-in Sub-Agents

Claude Code includes three built-in sub-agents available out of the box:

### Explore Agent

Fast, lightweight agent optimized for **read-only** codebase exploration.

| Property | Value |
|----------|-------|
| **Model** | Haiku (fast, low-latency) |
| **Mode** | Strictly read-only |
| **Tools** | Glob, Grep, Read, Bash (read-only: ls, git status, git log, git diff, find, cat, head, tail) |

**Thoroughness levels** (specify when invoking):
- `quick` - Fast searches, targeted lookups
- `medium` - Balanced speed and thoroughness
- `very thorough` - Comprehensive analysis across multiple locations

**When Claude uses it**: Searching/understanding codebase without making changes. Findings don't bloat the main conversation.

```
User: Where are errors from the client handled?
Claude: [Invokes Explore with "medium" thoroughness]
       → Returns: src/services/process.ts:712
```

### Plan Agent

Specialized for **plan mode** research and information gathering.

| Property | Value |
|----------|-------|
| **Model** | Sonnet |
| **Mode** | Read-only research |
| **Tools** | Read, Glob, Grep, Bash |
| **Invocation** | Automatic in plan mode |

**When Claude uses it**: In plan mode when researching codebase to create a plan. Prevents infinite nesting (sub-agents cannot spawn sub-agents).

### General-Purpose Agent

Capable agent for complex, multi-step tasks requiring both exploration AND action.

| Property | Value |
|----------|-------|
| **Model** | Sonnet |
| **Mode** | Read AND write |
| **Tools** | All tools |
| **Purpose** | Complex research, multi-step operations, code modifications |

**When Claude uses it**:
- Task requires both exploration and modification
- Complex reasoning needed to interpret search results
- Multiple strategies may be needed
- Task has multiple dependent steps

---

## Creating Custom Sub-Agents

### File Locations

| Type | Location | Scope | Priority |
|------|----------|-------|----------|
| Project | `.claude/agents/` | Current project only | Highest |
| User | `~/.claude/agents/` | All projects | Lower |
| CLI | `--agents '{...}'` | Current session | Middle |

When names conflict, project-level takes precedence.

### File Format

Markdown files with YAML frontmatter:

```yaml
---
name: code-reviewer
description: Expert code reviewer. Use proactively after code changes.
tools: Read, Grep, Glob, Bash
model: inherit
permissionMode: default
skills: project-workflow
hooks:
  PostToolUse:
    - matcher: "Edit|Write"
      hooks:
        - type: command
          command: "./scripts/run-linter.sh"
---

Your sub-agent's system prompt goes here.

Include specific instructions, best practices, and constraints.
```

### Configuration Fields

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Unique identifier (lowercase, hyphens) |
| `description` | Yes | When Claude should use this agent |
| `tools` | No | Comma-separated list. Omit = inherit all tools |
| `model` | No | `sonnet`, `opus`, `haiku`, or `inherit`. Default: sonnet |
| `permissionMode` | No | `default`, `acceptEdits`, `dontAsk`, `bypassPermissions`, `plan`, `ignore` |
| `skills` | No | Comma-separated skills to auto-load (sub-agents don't inherit parent skills) |
| `hooks` | No | `PreToolUse`, `PostToolUse`, `Stop` event handlers |

### Using /agents Command (Recommended)

```
/agents
```

Interactive menu to:
- View all sub-agents (built-in, user, project)
- Create new sub-agents with guided setup
- Edit existing sub-agents and tool access
- Delete custom sub-agents
- See which sub-agents are active

### CLI Configuration

```bash
claude --agents '{
  "code-reviewer": {
    "description": "Expert code reviewer. Use proactively after code changes.",
    "prompt": "You are a senior code reviewer. Focus on code quality, security, and best practices.",
    "tools": ["Read", "Grep", "Glob", "Bash"],
    "model": "sonnet"
  }
}'
```

---

## Using Sub-Agents

### Automatic Delegation

Claude proactively delegates based on:
- Task description in your request
- `description` field in sub-agent config
- Current context and available tools

**Tip**: Include "use PROACTIVELY" or "MUST BE USED" in description for more automatic invocation.

### Explicit Invocation

```
> Use the test-runner subagent to fix failing tests
> Have the code-reviewer subagent look at my recent changes
> Ask the debugger subagent to investigate this error
```

### Resumable Sub-Agents

Sub-agents can be resumed to continue previous conversations:

```
# Initial invocation
> Use the code-analyzer agent to review the auth module
[Agent completes, returns agentId: "abc123"]

# Resume with full context
> Resume agent abc123 and now analyze the authorization logic
```

**Use cases**:
- Long-running research across multiple sessions
- Iterative refinement without losing context
- Multi-step workflows with maintained context

### Disabling Sub-Agents

Add to settings.json permissions:

```json
{
  "permissions": {
    "deny": ["Task(Explore)", "Task(Plan)"]
  }
}
```

Or via CLI:
```bash
claude --disallowedTools "Task(Explore)"
```

---

## Delegation Patterns

### The Sweet Spot

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

### Core Prompt Template

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

### Batch Sizing

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

### Workflow Pattern

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

## Example Custom Sub-Agents

### Code Reviewer

```yaml
---
name: code-reviewer
description: Expert code review specialist. Proactively reviews code for quality, security, and maintainability. Use immediately after writing or modifying code.
tools: Read, Grep, Glob, Bash
model: inherit
---

You are a senior code reviewer ensuring high standards of code quality and security.

When invoked:
1. Run git diff to see recent changes
2. Focus on modified files
3. Begin review immediately

Review checklist:
- Code is clear and readable
- Functions and variables are well-named
- No duplicated code
- Proper error handling
- No exposed secrets or API keys
- Input validation implemented
- Good test coverage
- Performance considerations addressed

Provide feedback organized by priority:
- Critical issues (must fix)
- Warnings (should fix)
- Suggestions (consider improving)

Include specific examples of how to fix issues.
```

### Debugger

```yaml
---
name: debugger
description: Debugging specialist for errors, test failures, and unexpected behavior. Use proactively when encountering any issues.
tools: Read, Edit, Bash, Grep, Glob
---

You are an expert debugger specializing in root cause analysis.

When invoked:
1. Capture error message and stack trace
2. Identify reproduction steps
3. Isolate the failure location
4. Implement minimal fix
5. Verify solution works

Debugging process:
- Analyze error messages and logs
- Check recent code changes
- Form and test hypotheses
- Add strategic debug logging
- Inspect variable states

For each issue, provide:
- Root cause explanation
- Evidence supporting the diagnosis
- Specific code fix
- Testing approach
- Prevention recommendations

Focus on fixing the underlying issue, not the symptoms.
```

### Data Scientist

```yaml
---
name: data-scientist
description: Data analysis expert for SQL queries, BigQuery operations, and data insights. Use proactively for data analysis tasks and queries.
tools: Bash, Read, Write
model: sonnet
---

You are a data scientist specializing in SQL and BigQuery analysis.

When invoked:
1. Understand the data analysis requirement
2. Write efficient SQL queries
3. Use BigQuery command line tools (bq) when appropriate
4. Analyze and summarize results
5. Present findings clearly

Key practices:
- Write optimized SQL queries with proper filters
- Use appropriate aggregations and joins
- Include comments explaining complex logic
- Format results for readability
- Provide data-driven recommendations

Always ensure queries are efficient and cost-effective.
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

## Best Practices

1. **Start with Claude-generated agents**: Use `/agents` to generate initial config, then customize
2. **Design focused sub-agents**: Single, clear responsibility per agent
3. **Write detailed prompts**: Specific instructions, examples, constraints
4. **Limit tool access**: Only grant necessary tools (security + focus)
5. **Version control**: Check `.claude/agents/` into git for team sharing
6. **Use inherit for model**: Adapts to main conversation's model choice

---

## Performance Considerations

| Consideration | Impact |
|---------------|--------|
| **Context efficiency** | Agents preserve main context, enabling longer sessions |
| **Latency** | Sub-agents start fresh, may add latency gathering context |
| **Thoroughness** | Explore agent's thoroughness levels trade speed for completeness |

---

## Quick Reference

```
Built-in agents:
  Explore  → Haiku, read-only, quick/medium/thorough
  Plan     → Sonnet, plan mode research
  General  → Sonnet, all tools, read/write

Custom agents:
  Project  → .claude/agents/*.md (highest priority)
  User     → ~/.claude/agents/*.md
  CLI      → --agents '{...}'

Config fields:
  name, description (required)
  tools, model, permissionMode, skills, hooks (optional)

Delegation:
  Batch size: 5-8 items per agent
  Parallel: 2-4 agents simultaneously
  Prompt: 5-step (read → verify → check → evaluate → FIX)

Resume agents:
  > Resume agent [agentId] and continue...
```

---

## References

- [Official Sub-Agents Documentation](https://code.claude.com/docs/en/sub-agents)
- [Plugins Documentation](https://code.claude.com/docs/en/plugins)
- [Tools Documentation](https://code.claude.com/docs/en/tools)
- [Hooks Documentation](https://code.claude.com/docs/en/hooks)

---

**Last Updated**: 2026-01-09
