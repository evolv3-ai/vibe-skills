# Deep Debug Skill

Multi-agent investigation pattern for stubborn bugs that resist normal debugging.

## Origin

This skill emerged from a real debugging session where:
- We went in circles for ~30 minutes guessing at causes (caching? stream parsing?)
- User showed Network tab screenshot revealing **2 fetch requests** (the actual evidence)
- Launched 3 parallel agents that found the root cause in ~5 minutes
- Fix was a React useCallback dependency issue

## Key Insight

**Evidence before hypotheses.** The Network tab screenshot broke the loop. We should have gathered that evidence earlier using Chrome MCP tools.

## When to Invoke

- "I'm stuck on this bug"
- "We've tried multiple things and nothing works"
- "This is going in circles"
- "Can you do a deep investigation?"
- `/deep-debug`

## Requirements

- Chrome MCP tools (for browser bugs) - `mcp__claude-in-chrome__*`
- Access to spawn sub-agents: `debugger`, `code-reviewer`, `Explore`

## See Also

- Built-in `debugger` agent - Single-agent debugging
- `skills/agent-development/SKILL.md` - Agent patterns and when to delegate
