#!/bin/bash
set -euo pipefail

# sc-startup skill implementation
# Handles: validation, config loading, --fast mode, and agent orchestration

REPO_ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="$REPO_ROOT/.claude/sc-startup.yaml"

# Parse arguments
FAST_MODE=false
INIT_MODE=false
PR_MODE=false
PULL_MODE=false
READONLY_MODE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --fast) FAST_MODE=true ;;
    --init) INIT_MODE=true ;;
    --pr) PR_MODE=true ;;
    --pull) PULL_MODE=true ;;
    --readonly) READONLY_MODE=true ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
  shift
done

# Helper function to parse YAML values
get_yaml_value() {
  local file="$1"
  local key="$2"
  grep "^${key}:" "$file" | head -1 | cut -d':' -f2- | sed 's/^ *//' | sed 's/ *$//'
}

# Helper function to resolve path relative to repo root
resolve_path() {
  local path="$1"
  if [[ "$path" =~ ^/ ]]; then
    echo "$path"
  else
    echo "$REPO_ROOT/$path"
  fi
}

# Step 1: Validate config exists
if [[ ! -f "$CONFIG_FILE" ]]; then
  cat <<EOF
{
  "success": false,
  "data": null,
  "error": {
    "code": "CONFIG.MISSING",
    "message": "Configuration file not found: $CONFIG_FILE",
    "recoverable": true,
    "suggested_action": "Run '/sc-startup --init' to create configuration"
  }
}
EOF
  exit 0
fi

# Step 2: Load and validate config
STARTUP_PROMPT=$(get_yaml_value "$CONFIG_FILE" "startup-prompt")
CHECKLIST=$(get_yaml_value "$CONFIG_FILE" "check-list")
WORKTREE_SCAN=$(get_yaml_value "$CONFIG_FILE" "worktree-scan")
PR_ENABLED=$(get_yaml_value "$CONFIG_FILE" "pr-enabled")
WORKTREE_ENABLED=$(get_yaml_value "$CONFIG_FILE" "worktree-enabled")

# Validate required keys
if [[ -z "$STARTUP_PROMPT" ]] || [[ -z "$CHECKLIST" ]]; then
  cat <<EOF
{
  "success": false,
  "data": null,
  "error": {
    "code": "CONFIG.INVALID",
    "message": "Missing required config keys: startup-prompt or check-list",
    "recoverable": false
  }
}
EOF
  exit 0
fi

# Step 3: Fast mode - read prompt and exit
if [[ "$FAST_MODE" == "true" ]]; then
  PROMPT_PATH=$(resolve_path "$STARTUP_PROMPT")
  
  if [[ ! -f "$PROMPT_PATH" ]]; then
    cat <<EOF
{
  "success": false,
  "data": null,
  "error": {
    "code": "PROMPT.NOTFOUND",
    "message": "Startup prompt file not found: $PROMPT_PATH",
    "recoverable": true
  }
}
EOF
    exit 0
  fi
  
  # Read the prompt and create a summary
  PROMPT_CONTENT=$(cat "$PROMPT_PATH")
  PROMPT_LINES=$(echo "$PROMPT_CONTENT" | wc -l)
  PROMPT_FIRST_LINE=$(echo "$PROMPT_CONTENT" | head -1)
  
  cat <<EOF
{
  "success": true,
  "data": {
    "mode": "fast",
    "prompt_summary": {
      "path": "$STARTUP_PROMPT",
      "lines": $PROMPT_LINES,
      "first_line": "$PROMPT_FIRST_LINE"
    },
    "role": "$PROMPT_FIRST_LINE"
  },
  "message": "Fast mode: loaded startup prompt and exiting"
}
EOF
  exit 0
fi

# For other modes, we would continue with agent orchestration
# This is a minimal implementation focusing on the --fast path
cat <<EOF
{
  "success": false,
  "data": null,
  "error": {
    "code": "NOT_IMPLEMENTED",
    "message": "Full mode not yet implemented",
    "recoverable": false
  }
}
EOF
