#!/usr/bin/env bash
#
# session-scout.sh
# Shows recent Claude Code, Claude Desktop, and OpenCode sessions on macOS/Linux.
# Bash equivalent of Session-Scout.ps1 (Windows).
#
# Usage:
#   ./session-scout.sh                    # Show recent sessions (default: top 12)
#   ./session-scout.sh --top 20           # Show more sessions
#   ./session-scout.sh --csv              # Export to ~/.admin/logs/session-scout-YYYY-MM-DD.csv
#   ./session-scout.sh --file ~/out.csv   # Export to specified path

set -euo pipefail

# --- Defaults ---
TOP=12
CSV_MODE=false
OUT_FILE=""

# --- Parse args ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --top|-t)  TOP="$2"; shift 2 ;;
    --csv)     CSV_MODE=true; shift ;;
    --file|-f) OUT_FILE="$2"; CSV_MODE=true; shift 2 ;;
    --help|-h)
      echo "Usage: session-scout.sh [--top N] [--csv] [--file PATH]"
      echo ""
      echo "Options:"
      echo "  --top, -t N      Maximum sessions to display (default: 12)"
      echo "  --csv            Export to ~/.admin/logs/session-scout-YYYY-MM-DD.csv"
      echo "  --file, -f PATH  Export to specified CSV path"
      echo "  --help, -h       Show this help"
      exit 0
      ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# --- Platform detection ---
OS="$(uname -s)"
case "$OS" in
  Darwin) PLATFORM="macos" ;;
  Linux)  PLATFORM="linux" ;;
  *)      PLATFORM="unknown" ;;
esac

# Cross-platform helpers
get_mtime_epoch() {
  local file="$1"
  if [[ "$PLATFORM" == "macos" ]]; then
    stat -f '%m' "$file" 2>/dev/null
  else
    stat -c '%Y' "$file" 2>/dev/null
  fi
}

epoch_to_date() {
  local epoch="$1"
  if [[ "$PLATFORM" == "macos" ]]; then
    date -r "$epoch" '+%Y-%m-%d %H:%M:%S' 2>/dev/null
  else
    date -d "@$epoch" '+%Y-%m-%d %H:%M:%S' 2>/dev/null
  fi
}

epoch_to_hour_bucket() {
  local epoch="$1"
  if [[ "$PLATFORM" == "macos" ]]; then
    date -r "$epoch" '+%Y-%m-%d %H' 2>/dev/null
  else
    date -d "@$epoch" '+%Y-%m-%d %H' 2>/dev/null
  fi
}

# --- Path extraction from session content ---
extract_cwd_from_file() {
  local file="$1"
  # Read first 100 lines and grep for cwd/working_dir/projectRoot fields
  local path
  path=$(head -n 100 "$file" 2>/dev/null | \
    grep -oE '"(cwd|working_dir|workingDir|projectRoot|project_root|repoRoot|repo_root)"\s*:\s*"[^"]+"' | \
    head -1 | \
    sed -E 's/.*:\s*"([^"]+)".*/\1/' | \
    sed 's|\\\\|/|g')
  echo "$path"
}

# Decode Claude project slug to path
# Unix slugs: -home-user-dev-foo -> /home/user/dev/foo
decode_project_slug() {
  local slug="$1"
  if [[ "$slug" == -* ]]; then
    # Leading dash means root /, subsequent dashes are /
    echo "$slug" | sed 's|^-|/|' | sed 's|-|/|g'
  else
    echo ""
  fi
}

# --- Session collectors ---
# Each outputs lines: EPOCH\tTOOL\tPROJECT_PATH\tPROJECT\tSESSION_ID

find_claude_code_sessions() {
  local projects_dir="$HOME/.claude/projects"
  [[ -d "$projects_dir" ]] || return 0

  # Find *.jsonl excluding agent-*.jsonl, get mtime
  local count=0
  declare -A seen

  while IFS= read -r file; do
    [[ $count -ge $((TOP * 6)) ]] && break

    local basename
    basename=$(basename "$file")
    # Skip agent sessions
    [[ "$basename" == agent-* ]] && continue

    local dir_name
    dir_name=$(basename "$(dirname "$file")")
    local epoch
    epoch=$(get_mtime_epoch "$file") || continue
    [[ -z "$epoch" ]] && continue

    local hour_bucket
    hour_bucket=$(epoch_to_hour_bucket "$epoch")
    local dedup_key="${dir_name}|${hour_bucket}"

    # Deduplicate by project + hour
    [[ -n "${seen[$dedup_key]+x}" ]] && continue
    seen[$dedup_key]=1

    # Extract path from content
    local best_path
    best_path=$(extract_cwd_from_file "$file")

    # Fallback: decode project slug
    if [[ -z "$best_path" ]]; then
      best_path=$(decode_project_slug "$dir_name")
    fi

    # Extract session ID (UUID from filename)
    local session_id=""
    local file_base="${basename%.jsonl}"
    if [[ "$file_base" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]]; then
      session_id="$file_base"
    fi

    printf '%s\t%s\t%s\t%s\t%s\n' "$epoch" "Claude Code" "$best_path" "$dir_name" "$session_id"
    ((count++))
  done < <(find "$projects_dir" -type f -name '*.jsonl' -printf '%T@\t%p\n' 2>/dev/null | \
    sort -rn | cut -f2-)
}

find_claude_desktop_sessions() {
  local roots=()

  if [[ "$PLATFORM" == "macos" ]]; then
    roots=(
      "$HOME/Library/Application Support/Claude"
      "$HOME/Library/Application Support/Anthropic"
    )
  else
    roots=(
      "$HOME/.config/Claude"
      "$HOME/.config/Anthropic"
    )
  fi

  declare -A seen
  local count=0

  for root in "${roots[@]}"; do
    [[ -d "$root" ]] || continue

    while IFS= read -r file; do
      [[ $count -ge $TOP ]] && break

      local basename
      basename=$(basename "$file")
      local dir_name
      dir_name=$(basename "$(dirname "$file")")
      local epoch
      epoch=$(get_mtime_epoch "$file") || continue
      [[ -z "$epoch" ]] && continue

      local hour_bucket
      hour_bucket=$(epoch_to_hour_bucket "$epoch")
      local dedup_key="${dir_name}|${hour_bucket}"

      [[ -n "${seen[$dedup_key]+x}" ]] && continue
      seen[$dedup_key]=1

      local file_base="${basename%.*}"

      printf '%s\t%s\t%s\t%s\t%s\n' "$epoch" "Claude Desktop" "" "$dir_name" "$file_base"
      ((count++))
    done < <(find "$root" -type f \( \
        -name '*chat*' -o -name '*conversation*' -o -name '*transcript*' \
        -o -name '*history*' -o -name '*session*' -o -name '*messages*' \
      \) \( \
        -name '*.json' -o -name '*.jsonl' -o -name '*.txt' \
        -o -name '*.log' -o -name '*.sqlite' -o -name '*.db' \
      \) -printf '%T@\t%p\n' 2>/dev/null | sort -rn | cut -f2-)
  done
}

find_opencode_sessions() {
  local log_dir="$HOME/.local/share/opencode/log"
  [[ -d "$log_dir" ]] || return 0

  declare -A seen
  local count=0

  while IFS= read -r log_file; do
    [[ $count -ge $TOP ]] && break

    local basename
    basename=$(basename "$log_file")
    local session_id="${basename%.log}"

    # Extract directory= paths from log content
    local dirs=()
    while IFS= read -r dir; do
      [[ -z "$dir" ]] && continue
      local dedup_key="${basename}|${dir}"
      [[ -n "${seen[$dedup_key]+x}" ]] && continue
      seen[$dedup_key]=1
      dirs+=("$dir")
    done < <(grep -oE 'directory=(/[^ ]+)' "$log_file" 2>/dev/null | \
      sed 's/directory=//' | sort -u | tail -10)

    # Multiple dirs = Desktop, single = CLI
    local tool_type="OpenCode CLI"
    [[ ${#dirs[@]} -gt 1 ]] && tool_type="OpenCode Desktop"

    local epoch
    epoch=$(get_mtime_epoch "$log_file") || continue

    for dir in "${dirs[@]}"; do
      [[ $count -ge $TOP ]] && break
      printf '%s\t%s\t%s\t%s\t%s\n' "$epoch" "$tool_type" "$dir" "" "$session_id"
      ((count++))
    done
  done < <(find "$log_dir" -maxdepth 1 -type f -name '*.log' -printf '%T@\t%p\n' 2>/dev/null | \
    sort -rn | head -15 | cut -f2-)
}

# --- macOS find compatibility ---
# macOS find lacks -printf, so we need a fallback
if [[ "$PLATFORM" == "macos" ]]; then
  # Redefine collectors to use stat instead of find -printf

  find_claude_code_sessions() {
    local projects_dir="$HOME/.claude/projects"
    [[ -d "$projects_dir" ]] || return 0

    local count=0
    declare -A seen

    while IFS= read -r file; do
      [[ $count -ge $((TOP * 6)) ]] && break

      local basename
      basename=$(basename "$file")
      [[ "$basename" == agent-* ]] && continue

      local dir_name
      dir_name=$(basename "$(dirname "$file")")
      local epoch
      epoch=$(stat -f '%m' "$file" 2>/dev/null) || continue
      [[ -z "$epoch" ]] && continue

      local hour_bucket
      hour_bucket=$(date -r "$epoch" '+%Y-%m-%d %H' 2>/dev/null)
      local dedup_key="${dir_name}|${hour_bucket}"

      [[ -n "${seen[$dedup_key]+x}" ]] && continue
      seen[$dedup_key]=1

      local best_path
      best_path=$(extract_cwd_from_file "$file")
      if [[ -z "$best_path" ]]; then
        best_path=$(decode_project_slug "$dir_name")
      fi

      local session_id=""
      local file_base="${basename%.jsonl}"
      if [[ "$file_base" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]]; then
        session_id="$file_base"
      fi

      printf '%s\t%s\t%s\t%s\t%s\n' "$epoch" "Claude Code" "$best_path" "$dir_name" "$session_id"
      ((count++))
    done < <(find "$projects_dir" -type f -name '*.jsonl' -exec stat -f '%m %N' {} + 2>/dev/null | \
      sort -rn | awk '{print $2}')
  }

  find_claude_desktop_sessions() {
    local roots=(
      "$HOME/Library/Application Support/Claude"
      "$HOME/Library/Application Support/Anthropic"
    )

    declare -A seen
    local count=0

    for root in "${roots[@]}"; do
      [[ -d "$root" ]] || continue

      while IFS= read -r file; do
        [[ $count -ge $TOP ]] && break

        local basename
        basename=$(basename "$file")
        local dir_name
        dir_name=$(basename "$(dirname "$file")")
        local epoch
        epoch=$(stat -f '%m' "$file" 2>/dev/null) || continue
        [[ -z "$epoch" ]] && continue

        local hour_bucket
        hour_bucket=$(date -r "$epoch" '+%Y-%m-%d %H' 2>/dev/null)
        local dedup_key="${dir_name}|${hour_bucket}"

        [[ -n "${seen[$dedup_key]+x}" ]] && continue
        seen[$dedup_key]=1

        local file_base="${basename%.*}"
        printf '%s\t%s\t%s\t%s\t%s\n' "$epoch" "Claude Desktop" "" "$dir_name" "$file_base"
        ((count++))
      done < <(find "$root" -type f \( \
          -name '*chat*' -o -name '*conversation*' -o -name '*transcript*' \
          -o -name '*history*' -o -name '*session*' -o -name '*messages*' \
        \) \( \
          -name '*.json' -o -name '*.jsonl' -o -name '*.txt' \
          -o -name '*.log' -o -name '*.sqlite' -o -name '*.db' \
        \) -exec stat -f '%m %N' {} + 2>/dev/null | sort -rn | awk '{print $2}')
    done
  }

  find_opencode_sessions() {
    local log_dir="$HOME/.local/share/opencode/log"
    [[ -d "$log_dir" ]] || return 0

    declare -A seen
    local count=0

    while IFS= read -r log_file; do
      [[ $count -ge $TOP ]] && break

      local basename
      basename=$(basename "$log_file")
      local session_id="${basename%.log}"

      local dirs=()
      while IFS= read -r dir; do
        [[ -z "$dir" ]] && continue
        local dedup_key="${basename}|${dir}"
        [[ -n "${seen[$dedup_key]+x}" ]] && continue
        seen[$dedup_key]=1
        dirs+=("$dir")
      done < <(grep -oE 'directory=(/[^ ]+)' "$log_file" 2>/dev/null | \
        sed 's/directory=//' | sort -u | tail -10)

      local tool_type="OpenCode CLI"
      [[ ${#dirs[@]} -gt 1 ]] && tool_type="OpenCode Desktop"

      local epoch
      epoch=$(stat -f '%m' "$log_file" 2>/dev/null) || continue

      for dir in "${dirs[@]}"; do
        [[ $count -ge $TOP ]] && break
        printf '%s\t%s\t%s\t%s\t%s\n' "$epoch" "$tool_type" "$dir" "" "$session_id"
        ((count++))
      done
    done < <(find "$log_dir" -maxdepth 1 -type f -name '*.log' -exec stat -f '%m %N' {} + 2>/dev/null | \
      sort -rn | head -15 | awk '{print $2}')
  }
fi

# --- Collect all sessions ---
all_sessions=$(
  find_claude_code_sessions
  find_claude_desktop_sessions
  find_opencode_sessions
)

# Sort by epoch descending, take top N
sorted=$(echo "$all_sessions" | sort -rn | head -n "$TOP")

if [[ -z "$sorted" ]]; then
  echo "No session artifacts found in expected locations."
  echo ""
  echo "Expected locations:"
  echo "  Claude Code:    ~/.claude/projects/*/*.jsonl"
  if [[ "$PLATFORM" == "macos" ]]; then
    echo "  Claude Desktop: ~/Library/Application Support/Claude/"
  else
    echo "  Claude Desktop: ~/.config/Claude/"
  fi
  echo "  OpenCode:       ~/.local/share/opencode/log/*.log"
  exit 0
fi

# --- Output ---
if [[ "$CSV_MODE" == true ]]; then
  # Determine output path
  if [[ -z "$OUT_FILE" ]]; then
    local_dir="$HOME/.admin/logs"
    mkdir -p "$local_dir"
    OUT_FILE="$local_dir/session-scout-$(date '+%Y-%m-%d').csv"
  fi

  echo "Tool,When,ProjectPath,Project,SessionId" > "$OUT_FILE"
  while IFS=$'\t' read -r epoch tool path project session_id; do
    when=$(epoch_to_date "$epoch")
    printf '"%s","%s","%s","%s","%s"\n' "$tool" "$when" "$path" "$project" "$session_id"
  done <<< "$sorted" >> "$OUT_FILE"

  echo "Wrote $(echo "$sorted" | wc -l | tr -d ' ') sessions to: $OUT_FILE"
else
  # Table output
  printf '%-28s %-20s %-35s %-25s %s\n' "Tool" "When" "ProjectPath" "Project" "SessionId"
  printf '%-28s %-20s %-35s %-25s %s\n' "----" "----" "-----------" "-------" "---------"

  while IFS=$'\t' read -r epoch tool path project session_id; do
    when=$(epoch_to_date "$epoch")
    printf '%-28s %-20s %-35s %-25s %s\n' "$tool" "$when" "$path" "$project" "$session_id"
  done <<< "$sorted"

  echo ""
  echo "Quick checks if sessions are missing:"
  echo "  Claude Code:  find ~/.claude/projects -name '*.jsonl' 2>/dev/null | wc -l"
  if [[ "$PLATFORM" == "macos" ]]; then
    echo "  Claude Desktop: ls ~/Library/Application\\ Support/Claude/"
  fi
fi
