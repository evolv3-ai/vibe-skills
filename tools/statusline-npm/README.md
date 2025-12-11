# 🧱 ContextBricks

**Real-time context tracking with brick visualization for Claude Code CLI**

[![npm version](https://img.shields.io/npm/v/contextbricks.svg)](https://www.npmjs.com/package/contextbricks)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A custom status line for Claude Code that displays accurate token usage with a beautiful brick visualization, plus git integration and session metrics.

![ContextBricks Status Line](https://raw.githubusercontent.com/jezweb/claude-skills/main/tools/statusline/assets/context-bricks.png)

## ✨ Features

- 🎯 **Native context_window support** (Claude Code 2.0.65+) - accurate token data
- 🔄 **Backwards compatible** - falls back to transcript parsing for older versions
- 🧱 **Brick visualization** showing context usage at a glance
- 🔧 **Git integration**: repo:branch [commit] message | github-repo *↑↓
- ⏱️ **Session duration**: track how long you've been working
- 💰 **Session cost**: API users see spending (hidden for Max subscribers)
- 📊 **Session metrics**: model name, lines changed, free space
- ⚡ **Zero config**: Auto-detects everything, just install and go

## 🚀 Quick Start

```bash
# Install and configure (one command!)
npx contextbricks

# Restart Claude Code to see your new status line
```

That's it! Your status line now shows real-time context tracking.

**Note**: Just `npx contextbricks` - no need for `init`! It runs the installer automatically.

## 📦 Installation Options

### Option 1: npx (Recommended - No Install)

```bash
npx contextbricks        # Runs installer automatically
```

### Option 2: Global Install

```bash
npm install -g contextbricks
contextbricks              # Also runs installer automatically
```

### Option 3: From Source

```bash
git clone https://github.com/jezweb/claude-skills
cd claude-skills/tools/statusline
./install.sh
```

## 🎨 What It Looks Like

**Line 1: Git + Model + Changes**
```
[Sonnet 4.5] claude-skills:main [5f2ce67] Remove auth-js skill | jezweb/claude-skills *↑2 | +145/-23
```

**Line 2: Context Bricks + Duration + Cost**
```
ctx [■■■■■■■■■■■■■■■■■□□□□□□□□□□□□□□□□□□□□□□□] 43% (86k/200k) | 113k free | 12m45s | $0.87
```

For Max subscribers (no API cost):
```
ctx [■■■■■■■■■■■■■■■■■□□□□□□□□□□□□□□□□□□□□□□□] 43% (86k/200k) | 113k free | 12m45s
```

**Color Legend:**
- 🟦 Cyan = Used context
- ⬜ Dim hollow = Free space

## 🔧 Requirements

- **Node.js** ≥14 (you already have this for Claude Code)
- **jq** - JSON processor
  ```bash
  sudo apt install jq  # Ubuntu/Debian
  brew install jq      # macOS
  ```
- **git** (optional) - For git info display

## 📚 Commands

```bash
contextbricks               # Interactive install (default - recommended)
contextbricks init          # Interactive install (same as above)
contextbricks install       # Install status line (non-interactive)
contextbricks uninstall     # Uninstall status line
contextbricks --help        # Show help
contextbricks --version     # Show version
```

## 🎯 How It Works

### Claude Code 2.0.65+ (Native)

ContextBricks v2.0 uses the **native `context_window` data** provided by Claude Code:

```json
{
  "context_window": {
    "total_input_tokens": 15234,
    "total_output_tokens": 4521,
    "context_window_size": 200000
  }
}
```

This gives you accurate, real-time token counts without any parsing overhead.

### Older Versions (Fallback)

For Claude Code < 2.0.65, ContextBricks falls back to parsing session transcript files (JSONL format) to get token usage.

## 🔄 Updates

```bash
# If installed globally
npm update -g contextbricks

# If using npx
npx contextbricks@latest init
```

## 📋 Changelog

### v2.0.0 (2025-12-11)
- **Native context_window support** - Uses Claude Code 2.0.65+ native data
- **Added session duration** - Shows time spent in session (e.g., `12m45s`)
- **Added session cost** - Shows API cost (only if > $0, hidden for Max subscribers)
- **Simplified visualization** - Single cyan colour for used context
- **Removed breakdown estimates** - No more estimated sys/tools/mcp/mem/msg
- **Backwards compatible** - Falls back to transcript parsing for older versions

### v1.0.x
- Initial release with transcript parsing and multi-colour breakdown

## 🐛 Troubleshooting

### Status line shows 0% (0k/200k tokens)

**Cause**: jq not installed or no context data available (new session)

**Fix**:
```bash
# Check jq
which jq || sudo apt install jq

# Test with native data
echo '{"context_window":{"total_input_tokens":50000,"total_output_tokens":5000,"context_window_size":200000},"model":{"display_name":"Sonnet 4.5"},"workspace":{"current_dir":"'"$PWD"'"},"cost":{"total_duration_ms":300000}}' | ~/.claude/statusline.sh
```

### Git info not showing

**Cause**: Not in a git repository

**Fix**: Initialize git or cd into a git repo

### Brick visualization looks wrong

**Cause**: Terminal color support

**Fix**: Ensure your terminal supports 256 colors
```bash
export TERM=xterm-256color
```

## 🤝 Contributing

Found a bug or have a feature request?

- GitHub: https://github.com/jezweb/claude-skills
- Issues: https://github.com/jezweb/claude-skills/issues

## 📄 License

MIT License - See [LICENSE](./LICENSE)

## 🙏 Credits

- Part of the [claude-skills](https://github.com/jezweb/claude-skills) collection
- Inspired by [ccstatusline](https://github.com/sirmalloc/ccstatusline)
- Token parsing approach from [codelynx.dev](https://codelynx.dev/posts/calculate-claude-code-context)

## 📖 Full Documentation

For complete documentation, customization options, and advanced usage, see:
[Full Documentation](https://github.com/jezweb/claude-skills/tree/main/tools/statusline)

---

**Made with ❤️ for the Claude Code community**
