# Claude Code Custom Status Line

A custom status line for Claude Code CLI that displays real-time context tracking, git information, and session metrics with a beautiful brick visualization.

![ContextBricks Status Line](assets/context-bricks.png)

## ✨ Features

### Real-Time Context Tracking
- **Accurate token usage** from Claude Code's transcript files
- **Brick visualization** showing context breakdown by category
- **Model-aware limits** (200k for all models in Claude Code)
- **Token breakdown**: System, Tools, MCP, Memory, Messages

### Git Integration
- Current **repo name and branch**
- Latest **commit hash and message**
- **GitHub repo** name (if remote exists)
- **Status indicators**:
  - `*` = uncommitted changes
  - `↑3` = ahead of remote by 3 commits
  - `↓2` = behind remote by 2 commits

### Session Metrics
- **Model name** (Sonnet 4.5, Opus 4, Haiku, etc.)
- **Lines changed** this session (+added/-removed)
- **Free space** remaining in context

## 📦 Installation

### Quick Install (Recommended)

**Via npm** (easiest - one command!):
```bash
npx contextbricks
```
No need for `init` - it runs the installer automatically!

**Or from source**:
```bash
cd tools/statusline
./install.sh
```

The installer will:
1. Check dependencies (jq, git)
2. Back up existing status line configuration
3. Install the script to `~/.claude/statusline.sh`
4. Update `~/.claude/settings.json`

**NPM Package**: [contextbricks](https://www.npmjs.com/package/contextbricks) - Install with one command!

### Manual Install

1. Copy the script:
   ```bash
   cp statusline.sh ~/.claude/statusline.sh
   chmod +x ~/.claude/statusline.sh
   ```

2. Update `~/.claude/settings.json`:
   ```json
   {
     "statusLine": {
       "type": "command",
       "command": "/home/YOUR_USERNAME/.claude/statusline.sh",
       "padding": 0
     }
   }
   ```

3. Restart Claude Code

## 🎨 What It Looks Like

### Line 1: Git + Model + Changes
```
[Sonnet 4.5] claude-skills:main [5f2ce67] Remove auth-js skill | jezweb/claude-skills *↑2 | +145/-23
```

### Line 2: Context Bricks + Breakdown
```
ctx [■■■■■■■■■■■■■■■■■□□□□□□□□□□□□□□□□□□□□□□□] 43% (86k/200k tokens) | sys:4k tools:16k mcp:2k mem:10k msg:54k | 113k free
```

**Color Legend:**
- 🔲 Dim white = System prompt
- 🟨 Yellow = Tools
- 🟪 Magenta = MCP servers
- 🟦 Blue = Memory/files
- 🟦 Cyan = Messages
- ⬜ Dim hollow = Free space

## 🔧 Requirements

- **jq** - JSON processor
  ```bash
  sudo apt install jq  # Ubuntu/Debian
  brew install jq      # macOS
  ```

- **git** (optional) - For git info display
  ```bash
  sudo apt install git
  ```

## 📖 How It Works

### Context Tracking

Claude Code stores session transcripts in JSONL format at:
```
~/.claude/projects/{project-dir}/{session-id}.jsonl
```

Each assistant message includes cumulative token usage:
```json
{
  "type": "assistant",
  "message": {
    "usage": {
      "input_tokens": 3,
      "cache_read_input_tokens": 93279,
      "cache_creation_input_tokens": 2822,
      "output_tokens": 467
    }
  }
}
```

The status line:
1. Receives `transcript_path` from Claude Code via JSON stdin
2. Parses the **last assistant message** (cumulative counts)
3. Sums all token types
4. Calculates percentage against model's context limit
5. Generates brick visualization proportional to usage

### Git Information

Queries git commands in the current workspace:
- `git rev-parse --show-toplevel` - Repo name
- `git branch --show-current` - Current branch
- `git rev-parse --short HEAD` - Commit hash
- `git log -1 --pretty=%s` - Commit message
- `git status --porcelain` - Uncommitted changes
- `git rev-list --count` - Ahead/behind tracking

## 🐛 Troubleshooting

### Status line shows 0% (0k/200k tokens)

**Cause**: Transcript file not found or parsing failed

**Debug**:
```bash
# Check if jq is installed
which jq

# Test the script manually
echo '{"transcript_path":"~/.claude/projects/test.jsonl","model":{"id":"claude-sonnet-4-5"}}' | ~/.claude/statusline.sh

# Check Claude Code logs
tail -f ~/.claude/logs/claude-code.log
```

### Brick visualization looks wrong

**Cause**: Terminal color support or ANSI escape codes

**Fix**:
- Ensure your terminal supports 256 colors
- Check `$TERM` environment variable
- Try: `export TERM=xterm-256color`

### Git info not showing

**Cause**: Not in a git repository or git not installed

**Fix**:
```bash
# Check if in git repo
git rev-parse --git-dir

# Install git
sudo apt install git
```

### Script runs slowly

**Cause**: Large transcript files (>10MB)

**Optimization**: The script uses `grep | tail -1` which is fast for most cases. For very large files, consider:
- Clearing old sessions: `rm ~/.claude/projects/*/old-session-*.jsonl`
- Using `tail -1000` to limit parsing

## 🎛️ Customization

### Change Brick Count

Edit `statusline.sh` line 166:
```bash
total_bricks=40  # Increase for more granular visualization
```

### Adjust Token Breakdown Estimates

Edit lines 140-147:
```bash
system_tokens=$((total_tokens * 2 / 100))   # Adjust percentages
tools_tokens=$((total_tokens * 8 / 100))
# ...
```

### Hide Git Status

Comment out lines 84-87:
```bash
# if [[ -n "$git_status" ]]; then
#     line1+=" \033[1;31m$git_status\033[0m"
# fi
```

### Compact Mode (Single Line)

Comment out line 197:
```bash
echo -e "$line1"
# echo -e "$brick_line"  # Disable context line
```

## 🗑️ Uninstallation

```bash
cd tools/statusline
./uninstall.sh
```

The uninstaller will:
1. Remove the status line script
2. Offer to restore settings.json from backup
3. Optionally delete backup files

Manual uninstall:
```bash
rm ~/.claude/statusline.sh
# Edit ~/.claude/settings.json and remove the "statusLine" section
```

## 🤝 Contributing

Found a bug or have a feature request?

1. Open an issue: [github.com/jezweb/claude-skills/issues](https://github.com/jezweb/claude-skills/issues)
2. Submit a PR with improvements
3. Share your customizations!

## 📄 License

MIT License - See [LICENSE](../../LICENSE) file

## 🙏 Credits

- Inspired by [ccstatusline](https://github.com/sirmalloc/ccstatusline)
- Token parsing approach from [codelynx.dev](https://codelynx.dev/posts/calculate-claude-code-context)
- Built for the [claude-skills](https://github.com/jezweb/claude-skills) repository

## 📚 Related Resources

- [Claude Code Documentation](https://code.claude.com/docs)
- [Status Line API](https://code.claude.com/docs/en/statusline)
- [Claude Code GitHub](https://github.com/anthropics/claude-code)

---

**Made with ❤️ for the Claude Code community**
