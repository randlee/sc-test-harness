# Setup

## Bootstrap

```bash
./scripts/bootstrap-test-repo.sh
```

This prepares `reports/trace.jsonl` and ensures required directories exist.

## Environment

- `ANTHROPIC_API_KEY` required for integration tests that call Claude.
- `CLAUDE_CLI_PATH` optional if `claude` is not on PATH.

## Local Claude Settings

Project hooks are configured in `.claude/settings.json`.
