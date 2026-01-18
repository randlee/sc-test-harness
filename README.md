# sc-test-harness

Instrumented test repository for Synaptic Canvas plugin testing with complete isolation from user plugins.

## Purpose

- Provide a **clean, isolated environment** for plugin integration tests
- Capture **hook traces** for tool and command activity
- Keep test data separate from user/global Claude state
- Support **reproducible testing** via HOME isolation

---

## Architecture

### Environment Isolation (Critical)

Tests run with **HOME override** to isolate from user plugins:

```bash
# Create unique isolated HOME per test
TEST_HOME="/tmp/claude-test-$(uuidgen)"
mkdir -p "$TEST_HOME/.claude"

# Run Claude with isolation
HOME="$TEST_HOME" claude -p "$PROMPT" \
    --setting-sources project \
    --dangerously-skip-permissions \
    --model "$MODEL"
```

This ensures:
- **No user plugins visible** - HOME override hides all user-scoped plugins
- **Project hooks work** - `--setting-sources project` loads `.claude/settings.json`
- **Clean slate** per test - Each test gets fresh environment

See [spike-1-clean-environment-configuration.md](docs/spike-1-clean-environment-configuration.md) for detailed experiments and findings.

### Hook Observability

All Claude events are captured via hooks in `.claude/settings.json`:

| Event | Purpose |
|-------|---------|
| SessionStart/End | Session lifecycle |
| UserPromptSubmit | Capture user prompts |
| PreToolUse/PostToolUse | Tool invocations with full input/output |
| SubagentStart/Stop | Subagent lifecycle tracking |
| Stop | When Claude stops responding |

Events are logged to `reports/trace.jsonl` as JSONL records.

See [spike-2-hook-observability.md](docs/spike-2-hook-observability.md) for event schemas and coverage analysis.

---

## Layout

```
sc-test-harness/
├── .claude/
│   └── settings.json      # Hook configuration
├── docs/
│   ├── HOOKS.md           # Hook event reference
│   ├── RESET.md           # Reset procedures
│   ├── SETUP.md           # Setup guide
│   ├── TRACE.md           # Trace format spec
│   ├── spike-1-*.md       # Isolation experiments
│   └── spike-2-*.md       # Observability experiments
├── pm/                    # Test prompts
├── reports/
│   └── trace.jsonl        # Hook event log
└── scripts/
    ├── bootstrap-test-repo.sh
    ├── reset-test-repo.sh
    └── log-hook.py        # Hook event logger
```

---

## Plugin Installation for Tests

To install plugins in an isolated test environment:

```bash
# 1. Copy marketplace data to isolated HOME
mkdir -p "$TEST_HOME/.claude/plugins"
cp ~/.claude/plugins/known_marketplaces.json "$TEST_HOME/.claude/plugins/"
cp -r ~/.claude/plugins/marketplaces "$TEST_HOME/.claude/plugins/"

# 2. Install plugin
HOME="$TEST_HOME" claude plugin install <plugin>@<marketplace> --scope project

# 3. Verify installation
HOME="$TEST_HOME" claude plugin list
```

---

## Usage with synaptic-canvas Test Harness

This repo is used by the pytest-based test harness in `synaptic-canvas/test-packages/`.

```bash
# Run plugin tests from synaptic-canvas
cd /path/to/synaptic-canvas
pytest test-packages/fixtures/ -v --open-report
```

The test harness:
1. Resets sc-test-harness to pristine state
2. Installs the plugin under test
3. Runs test prompts with expectations
4. Generates HTML/JSON reports

---

## Setup

```bash
./scripts/bootstrap-test-repo.sh
```

## Reset

```bash
./scripts/reset-test-repo.sh
```

---

## Key Documents

| Document | Description |
|----------|-------------|
| [spike-1-clean-environment-configuration.md](docs/spike-1-clean-environment-configuration.md) | HOME isolation mechanism |
| [spike-2-hook-observability.md](docs/spike-2-hook-observability.md) | Hook event schemas and coverage |
| [HOOKS.md](docs/HOOKS.md) | Hook configuration reference |
| [TRACE.md](docs/TRACE.md) | Trace JSONL format specification |

---

## Notes

- Provide `ANTHROPIC_API_KEY` when running integration tests
- Set `CLAUDE_CLI_PATH` if `claude` is not on PATH
- Plugin hooks live in `hooks/` at the plugin root (not in this repo)
