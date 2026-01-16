# sc-test-harness

Instrumented test repository for Synaptic Canvas local plugin testing.

## Setup

```bash
./scripts/bootstrap-test-repo.sh
```

## Reset

```bash
./scripts/reset-test-repo.sh
```

## Hooks

Hooks are configured in `hooks/hooks.json` and append JSON lines to `reports/trace.jsonl`.

## Notes

- Provide `ANTHROPIC_API_KEY` when running integration tests that use `claude -p`.
- Set `CLAUDE_CLI_PATH` if `claude` is not on PATH.
