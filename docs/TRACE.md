# Trace Format

Each line in `reports/trace.jsonl` is a JSON record:

```json
{
  "ts": "2025-01-16T04:12:00Z",
  "event": "PostToolUse",
  "cwd": "/path/to/repo",
  "stdin": { "...": "parsed hook payload when JSON" },
  "env": {
    "CLAUDE_AGENT_ID": "optional",
    "CLAUDE_AGENT_TASK": "optional",
    "CLAUDE_AGENT_STATUS": "optional",
    "CLAUDE_FILE_PATHS": "optional"
  },
  "pid": 12345,
  "ppid": 12344
}
```

Notes:
- `stdin` is parsed as JSON when possible; otherwise the raw stdin string is kept.
- `cwd` is the hook process working directory (`os.getcwd()`), not a normalized project-root field.
- `env` is currently an allowlisted subset, not a full environment dump.
- `pid` and `ppid` are included for correlation/debugging.
- Extend `scripts/log-hook.py` if you want broader env capture, stdout/stderr capture, or richer normalization.
