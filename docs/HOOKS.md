# Hooks

## Location

Project hooks live in `.claude/settings.json` under the `hooks` key.

Plugin hooks live in a plugin root at `hooks/hooks.json`.

## Events

Current events wired:
- `PreToolUse`
- `PostToolUse`
- `PreTask`
- `PostTask`
- `PreCommand`
- `PostCommand`

Each hook runs:

```
python3 scripts/log-hook.py --event <EventName>
```

## Output

Events are appended to `reports/trace.jsonl` as JSON lines.
See `docs/TRACE.md` for the record format.
