# sc-test-harness

Instrumented test repository for Synaptic Canvas local plugin testing.

## Purpose

- Provide a stable, resettable repo for local integration tests.
- Capture hook traces for tool and command activity.
- Keep logs out of user/global Claude state.

## Layout

```
sc-test-harness/
├── .claude/
│   └── settings.json
├── docs/
├── pm/
├── reports/
└── scripts/
```

## Hooks

Project hooks are configured in `.claude/settings.json` and append JSONL records to `reports/trace.jsonl`.
See `docs/HOOKS.md` for details.

## Setup

```bash
./scripts/bootstrap-test-repo.sh
```

## Reset

```bash
./scripts/reset-test-repo.sh
```

## Notes

- Provide `ANTHROPIC_API_KEY` when running integration tests that use `claude -p`.
- Set `CLAUDE_CLI_PATH` if `claude` is not on PATH.
- Plugin hooks live in `hooks/` at the plugin root (not in this repo).
