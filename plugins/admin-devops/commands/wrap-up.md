---
name: wrap-up
description: End-of-session ritual — close GitHub issues, document installs, commit/push changes, and capture lessons learned
allowed-tools:
  - Read
  - Write
  - Bash
  - Glob
  - Grep
  - AskUserQuestion
  - Task
argument-hint: "[--issue <N>] [--repo <path>] [--skip-git] [--skip-install] [--skip-issue] [--skip-lesson] [--skip-reconcile]"
---

# /wrap-up Command

A session-close ritual that ties off loose ends: GitHub issue closure, installation documentation, git commit/push, and optional knowledge capture. Auto-detects what happened during the session before prompting for anything.

Uses **docs-agent** for all file I/O (profile updates, log entries, lesson files, session notes).

## Flags

| Flag | Effect |
|------|--------|
| `--issue <N>` | Pre-fills GitHub issue number; skips the "which issue?" prompt; title confirmation still shown |
| `--repo <path>` | Specifies git repo path to check instead of cwd |
| `--skip-git` | Skips the git commit/push step entirely |
| `--skip-install` | Skips the installation documentation step entirely |
| `--skip-issue` | Skips the GitHub issue step entirely |
| `--skip-lesson` | Skips the knowledge capture step entirely |
| `--skip-reconcile` | Skips the library reconcile step entirely |

---

## Step 1: Profile Gate

Load the profile to get device info. **HALT if no profile exists.**

```bash
result=$("${CLAUDE_PLUGIN_ROOT}/skills/admin/scripts/test-admin-profile.sh")
if [[ $(echo "$result" | jq -r '.exists') != "true" ]]; then
    echo "No profile found. Run /setup-profile first."
    exit 1
fi
DEVICE=$(echo "$result" | jq -r '.device')
PLATFORM=$(echo "$result" | jq -r '.platform')
```

**PowerShell (Windows):**
```powershell
$result = pwsh -NoProfile -File "${CLAUDE_PLUGIN_ROOT}/skills/admin/scripts/Test-AdminProfile.ps1" | ConvertFrom-Json
if (-not $result.exists) {
    Write-Host "No profile found. Run /setup-profile first."
    exit 1
}
```

---

## Step 2: Silent Detection Phase

Before showing the user anything, run three silent checks. These pre-populate prompts and skip steps that have nothing to act on. **Never show output from this phase.**

### 2A: Git Status

```bash
REPO_PATH="${FLAG_REPO:-$(pwd)}"
GIT_STATUS=$(git -C "$REPO_PATH" status --porcelain 2>/dev/null)
GIT_AVAILABLE=$?   # 0 = git repo; non-zero = not a repo or git not installed
```

Store `$GIT_STATUS` (may be empty = clean tree) and `$GIT_AVAILABLE`.

### 2B: Recent Installs

Scan the last 50 lines of `~/.admin/logs/operations.log` for install entries from the past 4 hours:

```bash
if [[ -f ~/.admin/logs/operations.log ]]; then
    RECENT_INSTALLS=$(tail -50 ~/.admin/logs/operations.log | \
        grep -E '\[OK\].*[Ii]nstall' | \
        awk -v cutoff="$(date -d '4 hours ago' -Iseconds 2>/dev/null || date -v-4H -Iseconds)" \
        '$1 >= "["cutoff"]"')
fi
```

Parse tool names and versions from matching lines if present.

### 2C: GitHub CLI Check

```bash
GH_AVAILABLE=false
if command -v gh &>/dev/null && gh auth status &>/dev/null 2>&1; then
    GH_AVAILABLE=true
fi
```

---

## Step 3: Run Wrap-Up Steps

Print the header:

```
────────────────────────────────────────
  Admin Wrap-Up
────────────────────────────────────────
```

### Step 3A — GitHub Issue [Step 1/5]

**Skip entirely if**: `--skip-issue` flag is set.

**Skip with warning if**: `$GH_AVAILABLE` is false.
```
⚠️  gh CLI not found or not authenticated — issue step skipped.
```

**Otherwise**, ask:

```
[Step 1/5 — GitHub Issue]
  Was a GitHub issue resolved this session? [y/N]:
```

If user answers no → skip. If `--issue <N>` flag was provided → pre-fill the number and skip the number prompt.

If yes (or pre-filled):
1. Ask: `Issue number:` (skip if `--issue` flag provided)
2. Ask: `GitHub repo (e.g. evolv3-ai/vibe-skills):` — **always ask; do not infer** (user may be closing an issue in a different repo than their working directory)
3. Fetch issue title:
   ```bash
   gh issue view <N> -R <repo> --json title -q .title
   ```
4. Display fetched title for confirmation:
   ```
   → Fetching... "add a 'wrap-up' command to /admin skill" ✓
   ```
5. Ask: `Resolution note (one line, required):`
6. Confirm:
   ```
   Close issue #<N> on <repo>? [y/N]:
   ```
7. If yes:
   ```bash
   gh issue close <N> -R <repo> --comment "<resolution_note>"
   ```
   Report: `✅ Issue #<N> closed.`

**Error handling**:
- Issue already closed → `Issue #<N> is already closed — skipping.`
- Issue number not found → Show gh error, ask user to re-enter or skip; do not abort
- Network error → Show error, mark step as failed in summary; continue

Store result for commit message default: `CLOSED_ISSUE_N` and `CLOSED_ISSUE_TITLE`.

---

### Step 3B — Installation Check [Step 2/5]

**Skip entirely if**: `--skip-install` flag is set.

**Otherwise**:

If `$RECENT_INSTALLS` is non-empty, surface detected installs:
```
[Step 2/5 — Installation Check]
  Detected from log: docker v27.5.0 (apt, 2h ago)
  Confirm documented installs? [Y/n]:
```

If `$RECENT_INSTALLS` is empty, ask:
```
[Step 2/5 — Installation Check]
  Any tools or apps installed this session? [y/N]:
```

If user answers no → skip.

If user answers yes (with or without detections):
- If detections exist, ask: `Correct the list or press Enter to confirm: [docker v27.5.0]`
- If no detections, ask: `Which tools were installed? (comma-separated, e.g. ripgrep v14.1, jq v1.7):`

For each confirmed install, spawn **docs-agent** via Task tool to check and update the device profile:

```
Task: docs-agent
→ Check if profile .tools.<name> exists for device <DEVICE>.
→ If missing, create entry: { "present": true, "version": "<version>", "installedVia": "<manager>", "installStatus": "working", "lastChecked": "<ISO8601>" }
→ Log: [OK] Documented install: <name> v<version>
→ Return: { "tool": "<name>", "action": "created|already_logged" }
```

Report per tool:
- `→ Checking profile... docker already logged. ✅`
- `→ Profile updated: ripgrep v14.1 added. ✅`

---

### Step 3C — Library Reconcile [Step 3/5]

**Skip entirely if**: `--skip-reconcile` flag is set.

**Skip silently if**: `reconcile-library.sh` or `library.json` is not found.

```bash
ADMIN_SCRIPTS="${CLAUDE_PLUGIN_ROOT}/skills/admin/scripts"
LIBRARY_JSON="${HOME}/.claude/skills/library/library.json"

if [[ -x "$ADMIN_SCRIPTS/reconcile-library.sh" && -f "$LIBRARY_JSON" ]]; then
    DRIFT=$("$ADMIN_SCRIPTS/reconcile-library.sh" --json 2>/dev/null | python3 -c "
import json,sys
data=json.load(sys.stdin)
drift=[x for x in data if x['action']=='should_install']
if drift: print(str(len(drift))+' catalog entries not bound: '+', '.join(x['name']+'('+x['type']+')' for x in drift))
" 2>/dev/null || true)
fi
```

**If drift is empty** — skip this step entirely with no output.

**If drift is detected**:

```
[Step 3/5 — Library Reconcile]
  Library drift: 2 catalog entries not bound — infisical(mcp), napkin(skill)
  Resolve before committing? [y/N]:
```

If user answers no → skip silently. Report in summary: `Library: drift detected (deferred)`.

If user answers yes → for each unbound entry, instruct the user to run `/library use <name>` and wait for confirmation:
```
  Run: /library use infisical
  Run: /library use napkin
  Done? [y/N]:
```
After confirmation: report `Library: <N> entries bound` in summary.

---

### Step 3D — Git [Step 4/5]

**Skip entirely if**: `--skip-git` flag is set.

**Skip silently if**: `$GIT_AVAILABLE` is non-zero (not a git repo or git not installed).

**If working tree is clean** (`$GIT_STATUS` is empty):
```
[Step 4/5 — Git]
  Repo: <REPO_PATH>
  Working tree clean — nothing to commit.
```
Skip to Step 3E.

**If changes exist**:

```
[Step 4/5 — Git]
  Repo: <REPO_PATH>
  Changes detected:
    M  plugins/admin-devops/commands/wrap-up.md
    A  plugins/admin-devops/agents/docs-agent.md
  Commit these changes? [Y/n]:
```

If yes:

Build default commit message:
- If `$CLOSED_ISSUE_N` is set: `fix: resolve issue #<N> — <CLOSED_ISSUE_TITLE truncated to 50 chars>`
- Otherwise: `chore: session wrap-up`

Ask:
```
Commit message [<default>]:
```
User can edit or press Enter to use default.

Run:
```bash
git -C "$REPO_PATH" add -A && git -C "$REPO_PATH" commit -m "<message>"
```
Report: `✅ Committed (<N> files).`

Then ask:
```
Push to remote? [y/N]:
```

If yes:
```bash
git -C "$REPO_PATH" push
```
Report: `✅ Pushed to <remote>/<branch>.`

If no:
```
Committed locally. Push when ready: git push
```

**Error handling**:
- No remote configured → Commit succeeds; skip push with: `(no remote configured — push skipped)`
- Push rejected → Show git error; do not retry; report push as failed in summary

---

### Step 3E — Knowledge Capture [Step 5/5]

**Skip entirely if**: `--skip-lesson` flag is set.

**Always show this prompt** (no detection possible — only the user knows if something is worth capturing):

```
[Step 5/5 — Anything worth remembering?]
  Anything worth remembering from this session? (Enter to skip):
```

If user presses Enter with no input → skip silently.

If user types anything:

Spawn **docs-agent** via Task tool:

```
Task: docs-agent
→ Create ~/.admin/issues/issue_{YYYYMMDD}_{HHMMSS}_{slug}.md with:
    category: lesson
    status: resolved
    title: (first sentence or first 60 chars of input — extract naturally)
    ## Resolution: (full verbatim input)
    ## Context: (leave blank)
    ## Symptoms: (leave blank)
    tags: (best-effort keywords extracted from input; empty list is acceptable)
    device: <DEVICE>
    platform: <PLATFORM>
→ Return: { "file": "<full_path>" }
```

Report:
```
✅ Captured: ~/.admin/issues/issue_20260404_174500_wsl2_dns_fails_silently.md
```

---

## Step 4: Summary and Session Log

Print the summary block (always, even if all steps skipped):

```
────────────────────────────────────────
  Session Summary
────────────────────────────────────────
  GitHub:   #25 closed — evolv3-ai/vibe-skills
  Installs: docker v27.5.0 (already logged)
  Library:  2 entries bound (infisical, napkin)
  Git:      committed + pushed (2 files) → origin/main
  Lesson:   captured → issue_..._wsl2_dns_fails_silently.md
  Logged:   ~/.admin/logs/sessions.log
────────────────────────────────────────
```

Each line shows one of: the action taken, `skipped`, `none detected`, or `working tree clean`.

**Quiet session example**:
```
────────────────────────────────────────
  Session Summary
────────────────────────────────────────
  GitHub:   skipped
  Installs: none detected
  Library:  no drift
  Git:      working tree clean
  Lesson:   skipped
  Logged:   ~/.admin/logs/sessions.log
────────────────────────────────────────
```

### Session Log Entry

Spawn **docs-agent** via Task tool to write session note:

```
Task: docs-agent
→ Append to ~/.admin/logs/sessions.log:
    [<ISO8601>] [<DEVICE>] SESSION: wrap-up
      Actions: <comma-separated list of actions taken, e.g. "closed issue #25, committed 2 files, pushed to origin/main, captured lesson">
      Outcome: success | partial | none
      Issues: <issue IDs or URLs if closed, otherwise "none">
```

---

## Edge Cases

| Scenario | Behavior |
|----------|----------|
| `gh` CLI not installed | Skip GitHub step with: `⚠️ gh CLI not found — issue step skipped` |
| `gh` not authenticated | Skip GitHub step with: `⚠️ gh not authenticated — issue step skipped` |
| Issue already closed | `Issue #<N> is already closed — skipping.` — no error |
| Issue number not found | Show gh error, ask user to re-enter or skip |
| Not in a git repo | Skip git step silently |
| Git repo has no remote | Commit succeeds; push step skipped with: `(no remote configured — push skipped)` |
| `operations.log` doesn't exist | Skip install log scan silently; still ask install question |
| All steps skipped/empty | Print: `Session closed — nothing to track.` + still write sessions.log entry |
| User declines push | `Committed locally. Push when ready: git push` |
| Lesson prompt — empty input | Step skipped silently; summary shows `Lesson: skipped` |
| Lesson prompt — one-word input | docs-agent creates file; title = the word; resolution = the word |

---

## Examples

```
/wrap-up
/wrap-up --issue 25
/wrap-up --issue 25 --repo ~/dev/vibe-skills
/wrap-up --skip-git --skip-install
/wrap-up --skip-lesson
```
