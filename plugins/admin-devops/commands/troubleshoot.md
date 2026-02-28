---
name: troubleshoot
description: Track, diagnose, and resolve issues using markdown issue files
allowed-tools:
  - Read
  - Write
  - Bash
  - Glob
  - Grep
  - AskUserQuestion
argument-hint: "[new | list | show <id> | resolve <id> | search <term>]"
---

# /troubleshoot Command

Track, diagnose, and resolve issues using markdown files stored in `~/.admin/issues/`.

## Issue File Location

All issues are stored as markdown files:
```
~/.admin/issues/
├── ISSUE-001-git-ssh-not-working.md
├── ISSUE-002-docker-permission-denied.md
└── ISSUE-003-node-version-conflict.md
```

## SimpleMem Integration

When SimpleMem MCP tools are available, the troubleshoot command uses persistent memory for smarter issue handling:

### On `/troubleshoot new` - Query Past Issues

Before creating, check if a similar issue has been seen before:
```
memory_query: "What issues have occurred with {category} on {platform}?"
```

If relevant memories exist, surface them:
```
Memory recall: Similar issue found from 2026-02-10.
  Previous solution: Added user to docker group and restarted daemon.
  Consider: Is this the same root cause?
```

### On `/troubleshoot resolve` - Store Solution

After resolving an issue, store the solution for future recall:
```
memory_add:
  speaker: "admin:troubleshoot"
  content: "Resolved issue '{title}' ({category}) on {DEVICE}: {resolution_description}. Resolution type: {fixed/workaround/etc}."
```

### Graceful Degradation

If SimpleMem is unavailable, skip memory operations silently. Issue files in `~/.admin/issues/` are always the authoritative record.

---

## Workflow by Subcommand

### `/troubleshoot new` - Create New Issue

Use TUI to gather issue details:

#### Q1: Issue Category
Ask: "What category is this issue?"

| Option | Description |
|--------|-------------|
| Tool/Installation | Package manager, install failures |
| Configuration | PATH, environment variables, config files |
| MCP Server | Model Context Protocol issues |
| Network/SSH | Connectivity, authentication |
| Permission | Access denied, privilege issues |
| Other | General issues |

#### Q2: Issue Title
Ask: "Briefly describe the issue (one line)"

#### Q3: Issue Description
Ask: "What's happening? Include error messages if any."

#### Q4: Priority
Ask: "How urgent is this issue?"

| Option | Description |
|--------|-------------|
| High | Blocking work, needs immediate fix |
| Medium | Important but has workaround |
| Low | Minor inconvenience |

Then create the issue file:

**Template: `~/.admin/issues/ISSUE-{NNN}-{slug}.md`**

```markdown
---
id: ISSUE-001
title: Git SSH not working
category: Network/SSH
priority: high
status: open
created: 2026-02-04T12:00:00Z
updated: 2026-02-04T12:00:00Z
platform: windows
device: DESKTOP-ABC
---

# Git SSH not working

## Problem
Unable to push to GitHub via SSH. Getting "Permission denied (publickey)" error.

## Error Message
```
git@github.com: Permission denied (publickey).
fatal: Could not read from remote repository.
```

## Environment
- OS: Windows 11
- Shell: PowerShell 7
- Git version: 2.42.0
- SSH agent: OpenSSH

## Steps to Reproduce
1. Run `git push origin main`
2. Observe error

## Investigation Log
<!-- Add notes as you investigate -->

## Solution
<!-- Fill in when resolved -->

## Related Issues
<!-- Link to related issues if any -->
```

### `/troubleshoot list` - List All Issues

Read all files in `~/.admin/issues/` and display summary table:

```
ID       | Title                      | Status | Priority | Created
---------|----------------------------|--------|----------|----------
ISSUE-001| Git SSH not working        | open   | high     | 2026-02-04
ISSUE-002| Docker permission denied   | open   | medium   | 2026-02-03
ISSUE-003| Node version conflict      | closed | low      | 2026-02-02
```

Filter options:
- `--open` - Show only open issues
- `--closed` - Show only closed issues
- `--high` - Show only high priority

### `/troubleshoot show <id>` - Show Issue Details

Read and display the full issue file for the given ID.

If no ID provided, ask user to select from open issues.

### `/troubleshoot resolve <id>` - Resolve an Issue

Use TUI to gather resolution details:

#### Q1: Resolution Type
Ask: "How was this issue resolved?"

| Option | Description |
|--------|-------------|
| Fixed | Found and applied a fix |
| Workaround | Applied a temporary workaround |
| Not reproducible | Cannot reproduce the issue |
| Won't fix | Issue is not worth fixing |
| Duplicate | Same as another issue |

#### Q2: Solution Description
Ask: "Describe the solution or workaround"

Then update the issue file:
1. Set `status: closed`
2. Add `resolved: <timestamp>`
3. Add `resolution: <type>`
4. Fill in the Solution section

### `/troubleshoot search <term>` - Search Issues

Search all issue files for the given term:

```bash
grep -r "<term>" ~/.admin/issues/
```

Display matching issues with context.

## Issue File Format

### Frontmatter Fields

| Field | Required | Description |
|-------|----------|-------------|
| id | Yes | Unique issue ID (ISSUE-NNN) |
| title | Yes | Short description |
| category | Yes | Issue category |
| priority | Yes | high/medium/low |
| status | Yes | open/in_progress/closed |
| created | Yes | ISO timestamp |
| updated | Yes | ISO timestamp (auto-updated) |
| platform | No | OS/platform |
| device | No | Device hostname |
| resolved | No | Timestamp when resolved |
| resolution | No | How it was resolved |

### Investigation Log

Encourage users to add timestamped notes as they investigate:

```markdown
## Investigation Log

### 2026-02-04 12:30
Checked SSH key exists: `~/.ssh/id_rsa.pub` - YES
Checked SSH agent running: `ssh-add -l` - NO keys loaded

### 2026-02-04 12:35
Added key to agent: `ssh-add ~/.ssh/id_rsa`
Testing connection: `ssh -T git@github.com` - SUCCESS
```

## Helper Scripts

Create issue:
```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/new-admin-issue.sh"
new_admin_issue "Git SSH not working" "Network/SSH" "high"
```

Update issue:
```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/update-admin-issue.sh"
update_admin_issue "ISSUE-001" "status" "closed"
```

## Tips

- Use meaningful slugs in filenames for easy identification
- Add investigation notes with timestamps as you work
- Link related issues when patterns emerge
- Search before creating to avoid duplicates
- High-priority issues should block other work until resolved
