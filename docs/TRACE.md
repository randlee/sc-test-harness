# Trace Format

Each line in `reports/trace.jsonl` is a JSON record:

```json
{
  "ts": "2025-01-16T04:12:00Z",
  "event": "PostToolUse",
  "cwd": "/path/to/repo",
  "stdin": "..."
}
```

Notes:
- `stdin` is whatever payload Claude passes to the hook.
- Extend `scripts/log-hook.py` if you want to capture stdout/stderr or environment variables.
