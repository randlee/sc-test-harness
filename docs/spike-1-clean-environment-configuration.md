# Spike 1: Clean Environment Configuration

**Date**: 2026-01-16
**Goal**: Determine exactly how to isolate Claude from global plugins/settings when running tests in sc-test-harness.

## Executive Summary

**Recommended Isolation Approach**: Use `HOME=/tmp/claude-test-<unique-id>` override combined with `--setting-sources project`.

This provides complete isolation from user plugins while allowing project-local hooks and configurations to work correctly.

---

## Experiment Results

### Experiment 1: Baseline - What's currently loaded?

**Command**:
```bash
cd /Users/randlee/Documents/github/sc-test-harness
claude plugin list
```

**Output**:
```
Installed plugins:

  > p3-nuget-publishing@p3-claude-marketplace
    Version: 1.0.0
    Scope: user
    Status: enabled

  > sc-delay-tasks@synaptic-canvas
    Version: 0.7.0
    Scope: user
    Status: enabled

  > sc-git-worktree@synaptic-canvas
    Version: 0.7.0
    Scope: user
    Status: enabled

  > sc-github-issue@synaptic-canvas
    Version: 0.7.0
    Scope: user
    Status: enabled

  > sc-manage@synaptic-canvas
    Version: 0.7.0
    Scope: user
    Status: enabled

  > sc-startup@synaptic-canvas
    Version: 0.7.0
    Scope: project
    Status: disabled

  > tabz-chrome-full@tabz-chrome
    Version: 2.7.5
    Scope: user
    Status: enabled
```

**Finding**: 7 plugins total - 6 user-scoped (enabled) and 1 project-scoped (disabled). This is what we need to isolate from.

---

### Experiment 2: HOME override isolation

**Command**:
```bash
mkdir -p /tmp/claude-isolation-test/.claude
HOME=/tmp/claude-isolation-test claude plugin list
```

**Output**:
```
No plugins installed. Use `claude plugin install` to install a plugin.
```

**Finding**: HOME override completely hides all user-scoped plugins. This is the key isolation mechanism.

---

### Experiment 3: --setting-sources project

**Command**:
```bash
claude -p "Run: claude plugin list" --setting-sources project --dangerously-skip-permissions --model haiku
```

**Output**:
```
You have 7 plugins installed:
- p3-nuget-publishing (1.0.0) - For NuGet package publishing
- sc-delay-tasks (0.7.0) - For scheduling delayed or interval-based actions
... (all 7 plugins listed)
```

**Finding**: `--setting-sources project` alone does NOT exclude user-scoped plugins. It only affects which settings.json files are loaded, not plugin visibility.

---

### Experiment 4: Combined isolation (HOME + --setting-sources)

**Command**:
```bash
HOME=/tmp/claude-isolation-test claude -p "what commands and skills do you have available?" --setting-sources project --dangerously-skip-permissions --model haiku
```

**Output**: Claude listed skills from the sc-test-harness project's local `.claude/skills/` directory, NOT from user plugins.

**Finding**: With HOME override, Claude only sees skills/commands defined in the project's `.claude` directory. The skills visible came from local definitions, not user-installed plugins.

---

### Experiment 5: Verify hooks still work with isolation

**Command**:
```bash
rm -f reports/trace.jsonl
HOME=/tmp/claude-isolation-test claude -p "list files in current directory using ls" --setting-sources project --dangerously-skip-permissions --model haiku
cat reports/trace.jsonl
```

**Output** (trace.jsonl):
```json
{"ts": "2026-01-16T19:11:35Z", "event": "SessionStart", ...}
{"ts": "2026-01-16T19:11:35Z", "event": "UserPromptSubmit", ...}
{"ts": "2026-01-16T19:11:36Z", "event": "PreToolUse", "tool_name": "Bash", ...}
{"ts": "2026-01-16T19:11:36Z", "event": "PostToolUse", "tool_name": "Bash", ...}
{"ts": "2026-01-16T19:11:38Z", "event": "Stop", ...}
{"ts": "2026-01-16T19:11:38Z", "event": "SessionEnd", ...}
```

**Finding**: Hooks defined in the project's `.claude/settings.json` fire correctly even with HOME override. All events captured: SessionStart, UserPromptSubmit, PreToolUse, PostToolUse, Stop, SessionEnd.

---

### Experiment 6: Plugin installation with isolated HOME

**Experiment 6a - Initial attempt (failed)**:
```bash
HOME=/tmp/claude-isolation-test claude plugin install sc-startup@synaptic-canvas --scope project
```

**Output**:
```
Failed to install plugin "sc-startup@synaptic-canvas": Plugin "sc-startup" not found in marketplace "synaptic-canvas"
```

**Finding**: Plugin installation fails because the isolated HOME doesn't have access to marketplace registries stored in `~/.claude/plugins/marketplaces/` and `~/.claude/plugins/known_marketplaces.json`.

**Experiment 6b - With marketplace data copied**:
```bash
# Copy marketplace data to isolated HOME
cp ~/.claude/plugins/known_marketplaces.json /tmp/claude-isolation-test/.claude/plugins/
cp -r ~/.claude/plugins/marketplaces /tmp/claude-isolation-test/.claude/plugins/

# Then install
HOME=/tmp/claude-isolation-test claude plugin install sc-startup@synaptic-canvas --scope project
```

**Output**:
```
Successfully installed plugin: sc-startup@synaptic-canvas (scope: project)
```

**Finding**: If marketplace data is copied to the isolated HOME, plugin installation works. Installed plugins appear correctly with `plugin list`.

---

### Experiment 7: Truly clean project (no local .claude skills)

**Command**:
```bash
# Fresh temp project with no .claude directory
rm -rf /tmp/clean-test-project && mkdir -p /tmp/clean-test-project && cd /tmp/clean-test-project && git init
HOME=/tmp/claude-isolation-test2 claude -p "list all slash commands and skills" --setting-sources project --dangerously-skip-permissions --model haiku
```

**Output**:
```
I don't have any slash commands or skills currently available in this session. The available skill list is empty.
```

**Finding**: With isolated HOME and no local `.claude` directory, Claude has zero plugins/skills - only core built-in tools.

---

### Experiment 8: Minimal harness with hooks only

**Setup**:
```bash
# Create minimal test harness - only settings.json with hooks, no skills
mkdir -p /tmp/isolated-harness-test/.claude
cp /path/to/sc-test-harness/.claude/settings.json /tmp/isolated-harness-test/.claude/
mkdir -p /tmp/isolated-harness-test/scripts /tmp/isolated-harness-test/reports
cp /path/to/sc-test-harness/scripts/log-hook.py /tmp/isolated-harness-test/scripts/
cd /tmp/isolated-harness-test && git init

# Run with fresh isolated HOME
HOME=/tmp/claude-isolation-final claude -p "What plugins and skills do you have?" --setting-sources project --dangerously-skip-permissions --model haiku
```

**Output**: Hooks fired correctly, all events captured in `reports/trace.jsonl`.

**Finding**: A minimal test harness with only hooks (no skills/commands) works perfectly with HOME isolation.

---

## Summary Table

| Method | User Plugins Hidden | Project Plugins Work | Hooks Work | Notes |
|--------|---------------------|----------------------|------------|-------|
| No isolation (baseline) | No | Yes | Yes | All 7 plugins visible |
| `HOME=/tmp/...` only | Yes | No* | Yes | *No marketplace access for install |
| `--setting-sources project` only | No | Yes | Yes | Does NOT isolate plugins |
| `HOME=/tmp/...` + `--setting-sources project` | Yes | Yes** | Yes | **If marketplace data copied |
| Clean project + HOME override | Yes | N/A | Yes | Zero plugins, pure isolation |

---

## Recommended Isolation Approach

### For Test Harness Implementation

Use the following pattern for each test execution:

```bash
# Create unique isolated HOME for this test run
TEST_HOME="/tmp/claude-test-$(uuidgen)"
mkdir -p "$TEST_HOME/.claude"

# Run Claude with isolation
HOME="$TEST_HOME" claude -p "$PROMPT" \
    --setting-sources project \
    --dangerously-skip-permissions \
    --model "$MODEL"

# Clean up after test
rm -rf "$TEST_HOME"
```

### Key Configuration Points

1. **HOME override** (`HOME=/tmp/...`): Primary isolation mechanism - hides all user plugins
2. **--setting-sources project**: Ensures only project-local settings.json is used
3. **--dangerously-skip-permissions**: Required for non-interactive test execution
4. **Project .claude/settings.json**: Define hooks here for test event capture

### If You Need to Install Plugins for Testing

If a test requires specific plugins:

```bash
# Copy marketplace data to isolated HOME
mkdir -p "$TEST_HOME/.claude/plugins"
cp ~/.claude/plugins/known_marketplaces.json "$TEST_HOME/.claude/plugins/"
cp -r ~/.claude/plugins/marketplaces "$TEST_HOME/.claude/plugins/"

# Now install plugin in isolated environment
HOME="$TEST_HOME" claude plugin install $PLUGIN_NAME --scope project
```

---

## Gotchas and Limitations Discovered

### 1. Marketplace Access Requires Real HOME Data
Plugin installation fails with isolated HOME unless marketplace registry data is copied. This includes:
- `~/.claude/plugins/known_marketplaces.json`
- `~/.claude/plugins/marketplaces/` directory

### 2. `--setting-sources project` Does NOT Isolate Plugins
This flag only controls which `settings.json` files are loaded. Plugin visibility is controlled entirely by HOME.

### 3. Transcript Path Changes with HOME Override
With `HOME=/tmp/claude-isolation-test`, transcripts are written to:
```
/tmp/claude-isolation-test/.claude/projects/-Users-randlee-Documents-github-sc-test-harness/<session-id>.jsonl
```
Test harnesses should account for this path when reading transcripts.

### 4. Local Skills Directory Takes Precedence
Even with isolated HOME, skills defined in the project's `.claude/skills/` directory are available. For complete isolation, the test project should not have local skill definitions.

### 5. Environment Variables May Leak
Other environment variables (PATH, etc.) are inherited. For complete isolation, consider explicitly setting/unsetting relevant env vars.

---

## Implementation Checklist for sc-test-harness

- [x] Use HOME override for plugin isolation
- [ ] Create test runner script with unique HOME per test
- [ ] Ensure hooks are defined in project .claude/settings.json
- [ ] Add transcript path detection logic (handles HOME-based path)
- [ ] Document that user plugins will NOT be available in tests
- [ ] Add option to copy marketplace data if plugin tests needed
- [ ] Clean up temporary HOME directories after tests
