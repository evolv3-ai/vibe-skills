#!/bin/bash

# Claude Code Custom Status Line
# v3.1.0 - Context tracking RE-ENABLED with current_usage API
# Shows: Model | Repo:Branch [commit] message | GitHub | git status | lines changed
#        Context bricks | percentage | duration | cost
#
# Uses new current_usage field (Claude Code 2.0.70+) for accurate context tracking.
# See: https://code.claude.com/docs/en/statusline#context-window-usage

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

# Build Line 2: Context bricks + session info
# Get session duration (convert ms to HHh MMm format)
duration_ms=$(echo "$input" | jq -r '.cost.total_duration_ms // 0')
duration_hours=$((duration_ms / 3600000))
duration_min=$(((duration_ms % 3600000) / 60000))

# Get session cost (only show if > 0, for API users)
cost_usd=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')

# Get context window data using new current_usage field (Claude Code 2.0.70+)
total_tokens=$(echo "$input" | jq -r '.context_window.context_window_size // 200000')
current_usage=$(echo "$input" | jq -r '.context_window.current_usage // null')

if [[ "$current_usage" != "null" ]]; then
    # Use accurate current_usage data
    input_tokens=$(echo "$current_usage" | jq -r '.input_tokens // 0')
    cache_creation=$(echo "$current_usage" | jq -r '.cache_creation_input_tokens // 0')
    cache_read=$(echo "$current_usage" | jq -r '.cache_read_input_tokens // 0')

    # Calculate actual current context usage
    used_tokens=$((input_tokens + cache_creation + cache_read))
else
    # Fallback: no current_usage available yet (first message or older version)
    used_tokens=0
fi

# Calculate metrics
free_tokens=$((total_tokens - used_tokens))
if [[ $total_tokens -gt 0 ]]; then
    usage_pct=$(( (used_tokens * 100) / total_tokens ))
else
    usage_pct=0
fi

# Convert to 'k' format for display
used_k=$(( used_tokens / 1000 ))
total_k=$(( total_tokens / 1000 ))
free_k=$(( free_tokens / 1000 ))

# Generate brick visualization (40 bricks total)
total_bricks=40
if [[ $total_tokens -gt 0 ]]; then
    used_bricks=$(( (used_tokens * total_bricks) / total_tokens ))
else
    used_bricks=0
fi
free_bricks=$((total_bricks - used_bricks))

# Build brick line with single colour (cyan for used, dim white for free)
brick_line="ctx ["

# Used bricks (cyan)
for ((i=0; i<used_bricks; i++)); do
    brick_line+="\033[0;36m■\033[0m"
done

# Free bricks (dim/gray hollow squares)
for ((i=0; i<free_bricks; i++)); do
    brick_line+="\033[2;37m□\033[0m"
done

brick_line+="]"

brick_line+=" \033[1m${usage_pct}%\033[0m (${used_k}k/${total_k}k)"

# Add free space
brick_line+=" | \033[1;32m${free_k}k free\033[0m"

# Add duration (HHh MMm format)
brick_line+=" | ${duration_hours}h ${duration_min}m"

# Add cost only if non-zero, rounded to 2 decimal places
if command -v bc &> /dev/null; then
    if (( $(echo "$cost_usd > 0" | bc -l 2>/dev/null || echo "0") )); then
        cost_formatted=$(printf "%.2f" "$cost_usd" 2>/dev/null || echo "0.00")
        brick_line+=" | \033[0;33m\$${cost_formatted}\033[0m"
    fi
else
    # Fallback without bc: simple string comparison
    if [[ "$cost_usd" != "0" && "$cost_usd" != "0.0" && "$cost_usd" != "0.00" && -n "$cost_usd" ]]; then
        brick_line+=" | \033[0;33m\$${cost_usd}\033[0m"
    fi
fi

# Output both lines
echo -e "$line1"
echo -e "$brick_line"
