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

All issues are stored as markdown files with timestamp-based IDs:
```
~/.admin/issues/
├── issue_20260204_120000_git_ssh_not_working.md
├── issue_20260203_093015_docker_permission_denied.md
└── issue_20260202_155500_node_version_conflict.md
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
| troubleshoot | General troubleshooting |
| install | Package manager, install failures |
| devenv | Development environment issues |
| mcp | Model Context Protocol issues |
| skills | Skill/agent/command bugs |
| devops | Remote server or infrastructure issues |

#### Q2: Issue Title
Ask: "Briefly describe the issue (one line)"

#### Q3: Issue Description
Ask: "What's happening? Include error messages if any."

#### Q4: Tags
Ask: "Add tags for this issue (comma-separated keywords, e.g. `ssh,git,auth`)"

These tags make issues searchable. Use topic keywords, not severity words.

Then create the issue file using the helper script:

**Template: `~/.admin/issues/issue_{YYYYMMDD}_{HHMMSS}_{slug}.md`**

```markdown
---
id: issue_20260204_120000_git_ssh_not_working
device: DESKTOP-ABC
platform: wsl
status: open
category: troubleshoot
tags: [ssh, git, auth]
created: 2026-02-04T12:00:00Z
updated: 2026-02-04T12:00:00Z
related_logs:
  - logs/operations.log
github_issue_url:
---

# Git SSH not working

## Context
User was trying to push to GitHub. Received permission denied error.

## Symptoms
`git push origin main` returns:
```
git@github.com: Permission denied (publickey).
fatal: Could not read from remote repository.
```

## Hypotheses

## Actions Taken

## Resolution

## Verification

## Next Action
```

### `/troubleshoot list` - List All Issues

Read all files in `~/.admin/issues/` and display summary table:

```
ID                                           | Status | Category     | Created
---------------------------------------------|--------|--------------|----------
issue_20260204_120000_git_ssh_not_working    | open   | troubleshoot | 2026-02-04
issue_20260203_093015_docker_permission_denied| open  | install      | 2026-02-03
issue_20260202_155500_node_version_conflict  | closed | devenv       | 2026-02-02
```

Filter options:
- `--open` - Show only open issues
- `--closed` - Show only closed issues
- `--category <name>` - Filter by category (troubleshoot, install, devenv, mcp, skills, devops)

### `/troubleshoot show <id>` - Show Issue Details

Read and display the full issue file for the given ID.

The `<id>` can be:
- The full timestamp ID: `issue_20260204_120000_git_ssh_not_working`
- A partial match: `git_ssh` — the script will find the matching file

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
1. Set `status: resolved` in frontmatter
2. Update the `updated:` timestamp
3. Fill in the `## Resolution` section with the description
4. Fill in the `## Verification` section

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
| id | Yes | Timestamp-based ID: `issue_YYYYMMDD_HHMMSS_slug` |
| device | Yes | Device hostname |
| platform | Yes | wsl \| windows \| linux \| macos |
| status | Yes | open \| resolved \| needs-escalation |
| category | Yes | troubleshoot \| install \| devenv \| mcp \| skills \| devops |
| tags | Yes | List of keyword tags (not severity) |
| created | Yes | ISO timestamp |
| updated | Yes | ISO timestamp (auto-updated) |
| related_logs | No | Log files relevant to this issue |
| github_issue_url | No | GitHub issue URL if escalated |

### Investigation Log

Encourage users to add timestamped notes as they investigate:

```markdown
## Actions Taken

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
source "${CLAUDE_PLUGIN_ROOT}/skills/admin/scripts/new-admin-issue.sh"
new_admin_issue "Git SSH not working" "troubleshoot" "ssh,git,auth"
```

Update issue:
```bash
source "${CLAUDE_PLUGIN_ROOT}/skills/admin/scripts/update-admin-issue.sh"
update_admin_issue "issue_20260204_120000_git_ssh_not_working" "resolution" "Added SSH key to agent"
# Or resolve entirely:
update_admin_issue "issue_20260204_120000_git_ssh_not_working" --resolve
```

## Tips

- Use tags for topics (e.g., `ssh`, `docker`, `node`), not severity levels
- Partial ID matching works: `update_admin_issue "git_ssh"` finds `issue_..._git_ssh_not_working`
- Add investigation notes with timestamps as you work
- Search before creating to avoid duplicates
- For bugs in skills/agents/commands, see `references/escalation-policy.md` to escalate to GitHub
