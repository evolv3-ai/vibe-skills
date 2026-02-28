# Agent Teams Reference

Quick reference for deciding when and how to use Claude Code agent teams vs subagents in admin/devops operations.

**Requires**: `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` in settings.json or environment.

---

## Decision Matrix: Subagents vs Teams

| | Subagents | Agent Teams |
|---|---|---|
| **Context** | Own context; results return to caller | Own context; fully independent |
| **Communication** | Report results back only | Teammates message each other directly |
| **Coordination** | Main agent manages all work | Shared task list with self-coordination |
| **Best for** | Focused tasks where only result matters | Complex work requiring discussion |
| **Token cost** | Lower (results summarized back) | Higher (each teammate = separate instance) |

**Rule of thumb**: Use subagents when work is independent. Use teams when agents need to share findings, challenge theories, or coordinate in real-time.

---

## Cost Analysis

| Pattern | Token Usage | When Justified |
|---------|------------|----------------|
| Solo session | ~200k tokens | Standard single-agent work |
| 3-person team | ~440k tokens (2.2x) | Parallel coordination with cross-team communication |
| 5-person team | ~500k+ tokens | Large-scale parallel work |

**Plan-first workflow** to manage costs:
1. Plan solo (~10k tokens) - break work into tasks, define boundaries
2. Execute with team (~500k tokens) - parallel execution of approved plan

---

## Admin/DevOps Use Cases

### Use Teams

- **Multi-cloud parallel provisioning**: OCI + Hetzner + Contabo simultaneously
- **Multi-layer deployment**: Server + Docker + app + monitoring in parallel
- **Competing diagnostic hypotheses**: Network vs app vs config investigated simultaneously
- **Security audit from multiple angles**: Firewall, SSH, app, certificates

### Use Subagents (NOT Teams)

- Simple package installation
- Sequential dependency chains
- Single-server provisioning
- Any task where agents don't need to talk to each other

---

## Admin Agent Team Roster

All admin/devops agents are team-compatible:

| Agent | Model | Team Role | File Ownership |
|-------|-------|-----------|----------------|
| docs-agent | haiku | File manager - all writes | profiles, issues, logs |
| verify-agent | sonnet | Quality gate - validates work | none (read + Bash only) |
| tool-installer | sonnet | Software installer | none (delegates writes to docs-agent) |
| profile-validator | haiku | Static profile checker | none (read only) |
| mcp-bot | sonnet | MCP diagnostics | MCP config files only |
| server-provisioner | sonnet | Cloud infrastructure | provider API calls |
| deployment-coordinator | sonnet | App deployment | deployment scripts |

### File Ownership Rules

To prevent conflicts where two teammates edit the same file:

| File/Directory | Owner | Others |
|----------------|-------|--------|
| `~/.admin/profiles/*.json` | docs-agent | Read only |
| `~/.admin/issues/*.md` | docs-agent | Read only |
| `~/.admin/logs/*.log` | docs-agent | Read only |
| MCP config files | mcp-bot | Read only |
| Provider API calls | server-provisioner | Do not call |
| System commands (install) | tool-installer | Do not run |

---

## Orchestration Patterns

### Leader Pattern (Centralized Control)

Lead assigns specific tasks to specific teammates.

```
Lead: "Provisioner: provision OCI server"
Lead: "Deployer: deploy Coolify when server ready"
Lead: Waits, synthesizes results
```

Best for: Clear role separation, explicit handoffs.

### Pipeline Pattern (Sequential Dependencies)

Tasks auto-unblock as predecessors complete.

```
Task 1: Provision server (no deps)
Task 2: Install Docker (depends on 1)
Task 3: Deploy Coolify (depends on 2)
Task 4: Verify deployment (depends on 3)
```

Best for: Multi-step deployments.

### Swarm Pattern (Self-Organization)

Lead populates task list, generic teammates claim work.

```
Lead: Creates 15 tasks
Teammates: Poll → claim → complete → repeat
```

Best for: Independent parallel tasks (server hardening across identical VMs).

### Watchdog Pattern (Quality Gates)

Verify-agent validates work before tasks are marked complete.

```
Installer: Installs Docker, marks task complete
Verify-agent: Tests Docker is working, approves or rejects
```

Best for: Infrastructure tasks requiring verification.

---

## Task Sizing

**Optimal**: 5-6 tasks per teammate.

| Too Small | Just Right | Too Large |
|-----------|-----------|-----------|
| Coordination overhead exceeds benefit | Self-contained, clear deliverable | Too long without check-ins |
| Too much context switching | A function, a test, a server provision | Hard to reassign if stuck |

---

## Limitations

| Limitation | Workaround |
|------------|------------|
| No session resumption with teammates | Spawn new teammates after `/resume` |
| Task status can lag | Lead manually checks and nudges |
| One team per session | Clean up before starting new team |
| No nested teams | Only lead manages team |
| File conflicts (no merge) | Enforce file ownership boundaries |
| Split panes need tmux/iTerm2 | Use in-process mode on other terminals |

---

## Enable Agent Teams

**settings.json**:
```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

**Environment variable**:
```bash
export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1
```

**Display modes**: `auto` (default), `in-process` (any terminal), `split panes` (tmux/iTerm2).

---

*Source: [Official Claude Code Agent Teams Docs](https://code.claude.com/docs/en/agent-teams) + community research (2026-02)*
