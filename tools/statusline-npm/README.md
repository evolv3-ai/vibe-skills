# 🧱 ContextBricks

**Real-time context tracking with brick visualization for Claude Code CLI**

[![npm version](https://img.shields.io/npm/v/contextbricks.svg)](https://www.npmjs.com/package/contextbricks)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A custom status line for Claude Code that displays accurate token usage with a beautiful brick visualization, plus git integration and session metrics.

![ContextBricks Status Line](https://raw.githubusercontent.com/jezweb/claude-skills/main/tools/statusline/assets/context-bricks.png)

## ✨ Features

- 🎯 **Real-time context tracking** from Claude Code transcript files
- 🧱 **Brick visualization** showing token breakdown by category
- 🔧 **Git integration**: repo:branch [commit] message | github-repo *↑↓
- 📊 **Session metrics**: model name, lines changed, free space
- 🎨 **Model-aware**: Automatic context limits (200k for all models in Claude Code)
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

**Line 2: Context Bricks + Breakdown**
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

ContextBricks reads Claude Code's session transcript files (JSONL format) to get **real token usage** - the same data that the `/context` command shows.

Each assistant message includes cumulative token counts:
- `input_tokens` - New input
- `cache_read_input_tokens` - Cached tokens reused
- `cache_creation_input_tokens` - New cache entries
- `output_tokens` - Claude's response

The brick visualization shows proportional usage across categories, and git info is queried from your workspace.

## 🔄 Updates

```bash
# If installed globally
npm update -g contextbricks

# If using npx
npx contextbricks@latest init
```

## 🐛 Troubleshooting

### Status line shows 0% (0k/200k tokens)

**Cause**: jq not installed or transcript file not found

**Fix**:
```bash
# Check jq
which jq || sudo apt install jq

# Test manually
contextbricks install
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
