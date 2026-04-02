# Skill Bug Escalation Policy

When you hit a problem during an admin-devops operation, use this guide to decide whether it stays local or goes to GitHub.

---

## Triage: Escalate vs. Stay Local

### ESCALATE to GitHub Issues (evolv3-ai/vibe-skills)

These are bugs in the skill code itself — other devices will hit them too.

| Trigger | Example |
|---------|---------|
| Script in `skills/*/scripts/` fails due to a code error | `load-profile.sh` exits 1 with a syntax error |
| Agent uses a flag or parameter that doesn't exist | `Log-AdminEvent.ps1 -Tool "git"` — `-Tool` is not a valid param |
| Command references a script or skill that doesn't exist | `/deploy` calls `scripts/deploy-helper.sh` which is missing |
| Cross-platform pair is missing | `render-mcp-config.sh` exists but `Render-McpConfig.ps1` doesn't |
| `SKILL.md` has broken YAML frontmatter | Skill fails to load in Claude Code |
| Agent instruction produces consistently wrong output across devices | Hardcoded path `/home/wsladmin/` in a script |

### STAY LOCAL (don't escalate)

These are environment or config issues specific to the current device.

| Trigger | Handle with |
|---------|-------------|
| Missing Infisical secret | Configure secret, re-run renderer |
| Device profile missing or misconfigured | Run `/setup-profile` |
| MCP server not running or unreachable | Run `diagnose-mcp.sh` |
| File permission or path issue on this device only | Fix locally, log with `log-admin-event.sh` |
| Network connectivity failure | Operational issue — log locally |
| `gh` CLI not installed or not authenticated | Local environment setup needed |

**Rule of thumb**: If a fresh bootstrap on a different device would hit the same bug, escalate. If it only fails here, stay local.

---

## How to Escalate

1. **Create a local issue first** using `new-admin-issue.sh` with `category: skills`:
   ```bash
   scripts/new-admin-issue.sh
   # Set category to "skills" and fill in Context + Symptoms
   ```

2. **Fill in the issue file** — Context and Symptoms sections must have enough detail to reproduce the problem. Include the exact command run, error output, and affected file path. **Do NOT include secrets, API tokens, passwords, or internal IP addresses** — the GitHub repo was formerly public and issue content should always be safe for external visibility.

3. **Present to operator for confirmation**:
   ```
   This looks like a skill-level bug in [affected-file].
   Post to GitHub Issues on evolv3-ai/vibe-skills? (y/N):
   ```
   Default is **No**. Only proceed if the operator explicitly types `y` or `yes`.

4. **If yes** — run the escalation script with the path to the local issue file:
   ```bash
   scripts/post-skill-issue.sh ~/.admin/issues/<issue-file>.md
   ```
   The script will post to GitHub and write the issue URL back to the local file.

5. **If no** (or non-interactive session) — add `pending-github` to the issue's tags and continue:
   ```yaml
   tags: [pending-github]
   ```
   The issue stays local and can be escalated later.

---

## Fallback Behavior

If `gh` CLI is unavailable or returns an error, `post-skill-issue.sh` will:
- Print a warning and **not block** the current operation
- Set `status: needs-escalation` in the local issue file
- Exit 0 so the calling agent continues normally

---

## What Happens Next

GitHub Issues labeled `skill-bug` on `evolv3-ai/vibe-skills` are monitored by the skills-admin-wsl orchestrator. That orchestrator reads the issue, locates the affected files, builds a fix, commits to `main`, closes the issue with a commit reference, and (if the bug reveals a repeatable pattern) adds a new rule to `admin-rules.md`.

You don't need to follow up — the flywheel handles it.
