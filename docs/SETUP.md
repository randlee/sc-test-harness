# Setup

## Bootstrap

```bash
./scripts/bootstrap-test-repo.sh
```

This prepares `reports/trace.jsonl` and ensures required directories exist.

## Environment

- `ANTHROPIC_API_KEY` required for integration tests that call Claude.
- `CLAUDE_CLI_PATH` optional if `claude` is not on PATH.

## Clean Isolated Execution

For reliable harness runs, use an isolated `HOME` together with
`--setting-sources project` so user plugins and user settings do not leak into
the test session:

```bash
TEST_HOME="/tmp/claude-test-$(uuidgen)"
mkdir -p "$TEST_HOME/.claude"

HOME="$TEST_HOME" claude -p "$PROMPT" \
  --setting-sources project \
  --dangerously-skip-permissions \
  --model "${MODEL:-haiku}"
```

This is the baseline launch pattern established by the clean-environment spike.

## Local Claude Settings

Project hooks are configured in `.claude/settings.json`.
