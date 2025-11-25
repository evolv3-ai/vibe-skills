#!/bin/bash

# Claude Code Custom Status Line with Context Brick Visualization
# Shows: Model | Repo:Branch [commit] message | GitHub | git status | lines changed
#        Context usage as horizontal brick visualization (like /context)

# Read JSON from stdin
input=$(cat)

# Parse Claude data
model=$(echo "$input" | jq -r '.model.display_name // "Claude"' | sed 's/Claude //')
current_dir=$(echo "$input" | jq -r '.workspace.current_dir // env.PWD')
lines_added=$(echo "$input" | jq -r '.cost.total_lines_added // 0')
lines_removed=$(echo "$input" | jq -r '.cost.total_lines_removed // 0')

# Get git information (change to workspace directory)
cd "$current_dir" 2>/dev/null || cd "$HOME"

# Check if we're in a git repo
if git rev-parse --git-dir > /dev/null 2>&1; then
    repo_name=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" || echo "")
    branch=$(git branch --show-current 2>/dev/null || echo "detached")
    commit_short=$(git rev-parse --short HEAD 2>/dev/null || echo "")
    commit_msg=$(git log -1 --pretty=%s 2>/dev/null | cut -c1-40 || echo "")

    # Get GitHub repo (if remote exists)
    github_url=$(git config --get remote.origin.url 2>/dev/null)
    if [[ $github_url =~ github.com[:/](.+/.+)(\.git)?$ ]]; then
        github_repo="${BASH_REMATCH[1]%.git}"
    else
        github_repo=""
    fi

    # Git status indicators
    git_status=""
    if [[ -n $(git status --porcelain 2>/dev/null) ]]; then
        git_status="*"
    fi

    # Check ahead/behind remote
    upstream=$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null)
    if [[ -n "$upstream" ]]; then
        ahead=$(git rev-list --count "$upstream"..HEAD 2>/dev/null || echo "0")
        behind=$(git rev-list --count HEAD.."$upstream" 2>/dev/null || echo "0")
        [[ "$ahead" -gt 0 ]] && git_status="${git_status}↑${ahead}"
        [[ "$behind" -gt 0 ]] && git_status="${git_status}↓${behind}"
    fi
else
    repo_name="no-repo"
    branch=""
    commit_short=""
    commit_msg=""
    github_repo=""
    git_status=""
fi

# Build Line 1: Git + Model + Changes
line1=""

# Model in brackets
line1+="\033[1;36m[$model]\033[0m "

# Repo:Branch
if [[ -n "$repo_name" && "$repo_name" != "no-repo" ]]; then
    line1+="\033[1;32m$repo_name\033[0m"
    if [[ -n "$branch" ]]; then
        line1+=":\033[1;34m$branch\033[0m"
    fi
fi

# Commit info
if [[ -n "$commit_short" ]]; then
    line1+=" [\033[1;33m$commit_short\033[0m]"
    if [[ -n "$commit_msg" ]]; then
        line1+=" $commit_msg"
    fi
fi

# GitHub repo
if [[ -n "$github_repo" ]]; then
    line1+=" | \033[0;35m$github_repo\033[0m"
fi

# Git status indicators
if [[ -n "$git_status" ]]; then
    line1+=" \033[1;31m$git_status\033[0m"
fi

# Lines changed
if [[ "$lines_added" -gt 0 || "$lines_removed" -gt 0 ]]; then
    line1+=" | \033[0;32m+$lines_added\033[0m/\033[0;31m-$lines_removed\033[0m"
fi

# Build Line 2: Context Brick Visualization
# Parse REAL context data from transcript file

# Extract transcript path from JSON
transcript_path=$(echo "$input" | jq -r '.transcript_path // ""')

# Get model ID for context limit detection
model_id=$(echo "$input" | jq -r '.model.id // ""')

# Determine context limit based on model
# NOTE: While Opus 4/4.5 models have 1M context at API level, Claude Code CLI
# enforces a 200k limit for all models. Using 200k for accurate display.
case "$model_id" in
    *"opus-4"*) total_tokens=200000 ;;  # Claude Code limits to 200k
    *"sonnet-4"*|*"sonnet-3-7"*) total_tokens=200000 ;;
    *"haiku"*) total_tokens=200000 ;;
    *) total_tokens=200000 ;;  # Default
esac

# Parse transcript for token usage (if available)
if [[ -f "$transcript_path" && -s "$transcript_path" ]]; then
    # Parse JSONL transcript - get the LAST assistant message's token usage
    # (Each message contains cumulative context, so we only need the most recent)
    last_usage=$(grep '"type":"assistant"' "$transcript_path" 2>/dev/null | \
                 tail -1 | \
                 jq -r '.message.usage // null' 2>/dev/null)

    if [[ -n "$last_usage" && "$last_usage" != "null" ]]; then
        # Sum all token types from the last message
        used_tokens=$(echo "$last_usage" | jq '
            (.input_tokens // 0) +
            (.cache_read_input_tokens // 0) +
            (.cache_creation_input_tokens // 0) +
            (.output_tokens // 0)
        ')
    else
        used_tokens=0
    fi

    # Ensure we have a valid number
    if [[ ! "$used_tokens" =~ ^[0-9]+$ ]]; then
        used_tokens=0
    fi
else
    # No transcript available (new session)
    used_tokens=0
fi

# Estimate breakdown (rough approximation based on typical usage)
# In future: could parse tool definitions, CLAUDE.md, etc. for accuracy
system_tokens=$((total_tokens * 2 / 100))      # ~2% system prompt
tools_tokens=$((total_tokens * 8 / 100))       # ~8% tools
mcp_tokens=$((total_tokens * 1 / 100))         # ~1% MCP
memory_tokens=$((total_tokens * 5 / 100))      # ~5% memory/files
message_tokens=$((used_tokens - system_tokens - tools_tokens - mcp_tokens - memory_tokens))
if [[ $message_tokens -lt 0 ]]; then
    message_tokens=0
fi

free_tokens=$((total_tokens - used_tokens))

usage_pct=$(( (used_tokens * 100) / total_tokens ))

# Convert to 'k' format for display
used_k=$(( used_tokens / 1000 ))
total_k=$(( total_tokens / 1000 ))
free_k=$(( free_tokens / 1000 ))
system_k=$(( system_tokens / 1000 ))
tools_k=$(( tools_tokens / 1000 ))
mcp_k=$(( mcp_tokens / 1000 ))
memory_k=$(( memory_tokens / 1000 ))
message_k=$(( message_tokens / 1000 ))

# Generate brick visualization (40 bricks total for more granularity)
total_bricks=40
used_bricks=$(( (used_tokens * total_bricks) / total_tokens ))
free_bricks=$((total_bricks - used_bricks))

# Color codes for different types (matching /context)
# System: dim (gray), Tools: yellow, MCP: magenta, Memory: blue, Messages: cyan, Free: dim white
brick_line="ctx ["

# Calculate bricks per category (proportional to actual usage)
system_bricks=$(( (system_tokens * total_bricks) / total_tokens ))
tools_bricks=$(( (tools_tokens * total_bricks) / total_tokens ))
mcp_bricks=$(( (mcp_tokens * total_bricks) / total_tokens ))
memory_bricks=$(( (memory_tokens * total_bricks) / total_tokens ))
message_bricks=$(( (message_tokens * total_bricks) / total_tokens ))

# Draw bricks by category
brick_count=0

# System bricks (dim white)
for ((i=0; i<system_bricks && brick_count<used_bricks; i++)); do
    brick_line+="\033[2;37m■\033[0m"
    ((brick_count++))
done

# Tools bricks (yellow)
for ((i=0; i<tools_bricks && brick_count<used_bricks; i++)); do
    brick_line+="\033[0;33m■\033[0m"
    ((brick_count++))
done

# MCP bricks (magenta/pink)
for ((i=0; i<mcp_bricks && brick_count<used_bricks; i++)); do
    brick_line+="\033[0;35m■\033[0m"
    ((brick_count++))
done

# Memory bricks (blue)
for ((i=0; i<memory_bricks && brick_count<used_bricks; i++)); do
    brick_line+="\033[0;34m■\033[0m"
    ((brick_count++))
done

# Message bricks (cyan)
for ((i=0; i<message_bricks && brick_count<used_bricks; i++)); do
    brick_line+="\033[0;36m■\033[0m"
    ((brick_count++))
done

# Fill any remaining used bricks (in case of rounding)
while ((brick_count < used_bricks)); do
    brick_line+="\033[0;36m■\033[0m"
    ((brick_count++))
done

# Free bricks (dim/gray hollow squares)
for ((i=0; i<free_bricks; i++)); do
    brick_line+="\033[2;37m□\033[0m"
done

brick_line+="] \033[1m${usage_pct}%\033[0m (${used_k}k/${total_k}k tokens)"

# Add breakdown (simplified)
brick_line+=" | \033[2;37msys:${system_k}k\033[0m"
brick_line+=" \033[0;33mtools:${tools_k}k\033[0m"
brick_line+=" \033[0;35mmcp:${mcp_k}k\033[0m"
brick_line+=" \033[0;34mmem:${memory_k}k\033[0m"
brick_line+=" \033[0;36mmsg:${message_k}k\033[0m"
brick_line+=" | \033[1;32m${free_k}k free\033[0m"

# Output both lines
echo -e "$line1"
echo -e "$brick_line"
