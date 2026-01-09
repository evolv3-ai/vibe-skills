# Sub-Agent Patterns Skill

Effective patterns for delegating tasks to parallel sub-agents in Claude Code.

## Auto-Trigger Keywords

This skill should be suggested when the user mentions:

- "sub-agent", "sub-agents", "subagent"
- "parallel agents", "multiple agents"
- "Task tool", "launch agents"
- "bulk operations", "batch processing"
- "audit all", "update all", "check all"
- "swarm", "multi-agent"
- "delegate tasks"

## What This Skill Covers

1. **When to Delegate** - The "repetitive + judgment" sweet spot
2. **Prompt Templates** - 5-step structure that works consistently
3. **Batch Sizing** - 5-8 items per agent, 2-4 agents parallel
4. **Output Formats** - Structured reports for easy review
5. **Commit Strategy** - Agents edit, human commits
6. **Error Handling** - Retry, skip, or resolve conflicts

## Quick Example

```markdown
# Prompt template for sub-agents:

For each [item]:
1. Read [source file]
2. Verify with [external check]
3. Check [authoritative source]
4. Evaluate/score
5. FIX issues found  ← Key instruction

Items: [list of 5-8 items]
```

## When NOT to Use

- Single complex task (do it yourself)
- Simple find-replace (use scripts)
- Tasks with dependencies between items
- Creative/subjective decisions

## Production Tested

- Skill audits: 25 skills in ~5 minutes (parallel batches)
- Description optimization: 58 skills in ~3 minutes
- Multi-site updates: 12 sites with consistent changes

## Related Skills

- `project-planning` - For planning complex multi-phase work
- `project-workflow` - For session management and handoffs
